// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum ConversionEvent {
    case log(LogEntry)
    case progress(Double, String)
}

typealias ConversionEventHandler = @Sendable (ConversionEvent) async -> Void

actor ConversionCoordinator {
    private let scanner: FileScanner
    private let engine: ConversionEngine
    private let fileManager: FileManager

    private var cancelRequested = false

    init(
        scanner: FileScanner = FileScanner(),
        engine: ConversionEngine = ConversionEngine(),
        fileManager: FileManager = .default
    ) {
        self.scanner = scanner
        self.engine = engine
        self.fileManager = fileManager
    }

    func analyze(
        options: ConversionOptions,
        eventHandler: ConversionEventHandler? = nil
    ) async throws -> ConversionStats {
        resetCancellationFlag()

        let scanResult = try scanner.scan(options: options)

        var stats = ConversionStats()
        stats.totalScanned = scanResult.totalScanned
        stats.totalMatched = scanResult.matchedFiles.count
        stats.ignored = scanResult.totalIgnored

        if let eventHandler {
            await eventHandler(.progress(
                0.05,
                "Analyse: \(scanResult.totalScanned) fichier(s) détecté(s), profil \(options.profile.displayName)"
            ))
            for entry in scanResult.logs {
                if isCancellationRequested() {
                    throw MuniConvertError.cancelled
                }
                await eventHandler(.log(entry))
            }
            await eventHandler(.progress(
                1.0,
                "Analyse terminée — \(scanResult.matchedFiles.count) correspondant(s) sur \(scanResult.totalScanned) fichier(s)"
            ))
        }

        return stats
    }

    func convert(
        options: ConversionOptions,
        libreOfficeExecutable: URL?,
        eventHandler: ConversionEventHandler? = nil
    ) async throws -> ConversionStats {
        resetCancellationFlag()

        if !options.dryRun, libreOfficeExecutable == nil {
            throw MuniConvertError.libreOfficeNotFound
        }

        let scanResult = try scanner.scan(options: options)

        var stats = ConversionStats()
        stats.totalScanned = scanResult.totalScanned
        stats.totalMatched = scanResult.matchedFiles.count
        stats.ignored = scanResult.totalIgnored

        if let eventHandler {
            let modeLabel = options.dryRun ? "Simulation" : "Conversion"
            await eventHandler(.progress(
                0.03,
                "\(modeLabel): \(scanResult.totalScanned) fichier(s) scanné(s), \(scanResult.matchedFiles.count) à traiter"
            ))
            for entry in scanResult.logs {
                if isCancellationRequested() {
                    throw MuniConvertError.cancelled
                }
                await eventHandler(.log(entry))
            }
        }

        let totalToProcess = scanResult.matchedFiles.count
        guard totalToProcess > 0 else {
            if let eventHandler {
                await eventHandler(.progress(1.0, "Aucun fichier correspondant au profil"))
            }
            return stats
        }

        for (index, sourceFile) in scanResult.matchedFiles.enumerated() {
            if isCancellationRequested() {
                throw MuniConvertError.cancelled
            }

            let progressStart = Double(index) / Double(totalToProcess)
            if let eventHandler {
                let modeLabel = options.dryRun ? "Simulation" : "Conversion"
                await eventHandler(.progress(
                    progressStart,
                    "\(modeLabel) \(index + 1)/\(totalToProcess): \(sourceFile.lastPathComponent)"
                ))
            }

            var targetPath = ""

            do {
                let resolution = try PathUtilities.resolveTargetURL(
                    for: sourceFile,
                    options: options,
                    fileManager: fileManager
                )

                guard let targetURL = resolution.targetURL else {
                    stats.skippedExisting += 1
                    if let eventHandler {
                        await eventHandler(.log(LogEntry(
                            sourcePath: sourceFile.path,
                            status: .skippedExisting,
                            message: "Fichier cible déjà présent (politique: ignorer)"
                        )))
                        let progressEnd = Double(index + 1) / Double(totalToProcess)
                        let message = options.dryRun
                            ? "Simulation \(index + 1)/\(totalToProcess) terminée"
                            : "Conversion \(index + 1)/\(totalToProcess) terminée"
                        await eventHandler(.progress(progressEnd, message))
                    }
                    continue
                }

                targetPath = targetURL.path

                if options.dryRun {
                    stats.dryRun += 1
                    if let eventHandler {
                        await eventHandler(.log(LogEntry(
                            sourcePath: sourceFile.path,
                            status: .dryRun,
                            outputPath: targetURL.path,
                            message: "Simulation: conversion non exécutée"
                        )))
                    }
                } else {
                    guard let libreOfficeExecutable else {
                        throw MuniConvertError.libreOfficeNotFound
                    }

                    let job = FileConversionJob(
                        sourceURL: sourceFile,
                        targetURL: targetURL,
                        profile: options.profile
                    )

                    let details = try engine.convert(
                        job: job,
                        libreOfficeExecutable: libreOfficeExecutable,
                        overwriteIfNeeded: options.collisionPolicy == .overwrite
                    )

                    if isCancellationRequested() {
                        throw MuniConvertError.cancelled
                    }

                    stats.converted += 1
                    if let eventHandler {
                        await eventHandler(.log(LogEntry(
                            sourcePath: sourceFile.path,
                            status: .converted,
                            outputPath: targetURL.path,
                            message: details
                        )))
                    }
                }
            } catch {
                if isCancellationRequested() {
                    throw MuniConvertError.cancelled
                }

                stats.errors += 1
                if let eventHandler {
                    await eventHandler(.log(LogEntry(
                        sourcePath: sourceFile.path,
                        status: .failed,
                        outputPath: targetPath,
                        message: error.localizedDescription
                    )))
                }
            }

            let progressEnd = Double(index + 1) / Double(totalToProcess)
            if let eventHandler {
                let message = options.dryRun
                    ? "Simulation \(index + 1)/\(totalToProcess) terminée"
                    : "Conversion \(index + 1)/\(totalToProcess) terminée"
                await eventHandler(.progress(progressEnd, message))
            }
        }

        if let eventHandler {
            let modeLabel = options.dryRun ? "Simulation" : "Conversion"
            await eventHandler(.progress(1.0, "\(modeLabel) terminée — convertis: \(stats.converted), simulation: \(stats.dryRun), ignorés: \(stats.ignored), erreurs: \(stats.errors)"))
        }

        return stats
    }

    func cancelCurrentRun() {
        cancelRequested = true
        engine.cancelCurrentProcess()
    }

    private func resetCancellationFlag() {
        cancelRequested = false
    }

    private func isCancellationRequested() -> Bool {
        cancelRequested || Task.isCancelled
    }
}
