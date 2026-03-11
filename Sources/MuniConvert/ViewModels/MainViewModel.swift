// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Foundation
import SwiftUI

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum RunState {
    case idle
    case running
    case completed
    case cancelled
    case failed

    var displayName: String {
        switch self {
        case .idle:
            return "Prêt"
        case .running:
            return "En cours"
        case .completed:
            return "Terminé"
        case .cancelled:
            return "Annulé"
        case .failed:
            return "Erreur"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .running:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .orange
        case .failed:
            return .red
        }
    }
}

@MainActor
final class MainViewModel: ObservableObject {
    @Published var sourceFolderURL: URL? {
        didSet { persistSettings() }
    }
    @Published var outputFolderURL: URL? {
        didSet { persistSettings() }
    }

    @Published var includeSubdirectories: Bool = true {
        didSet { persistSettings() }
    }
    @Published var useSeparateOutputFolder: Bool = false {
        didSet { persistSettings() }
    }
    @Published var preserveRelativeStructure: Bool = false {
        didSet { persistSettings() }
    }
    @Published var dryRunOnly: Bool = false {
        didSet { persistSettings() }
    }
    @Published var ignoreHiddenFiles: Bool = true {
        didSet { persistSettings() }
    }

    @Published var selectedProfileID: String? {
        didSet { persistSettings() }
    }
    @Published var collisionPolicy: CollisionPolicy = .skipExisting {
        didSet { persistSettings() }
    }

    @Published var libreOfficePath: String = "" {
        didSet { persistSettings() }
    }
    @Published var libreOfficeFound: Bool = false
    @Published var libreOfficeVersion: String = ""
    @Published var libreOfficeMessage: String = "Non vérifié"

    @Published var logs: [LogEntry] = []
    @Published var stats = ConversionStats()
    @Published var progress: Double = 0
    @Published var progressMessage: String = "Prêt"
    @Published var isRunning: Bool = false
    @Published var runState: RunState = .idle
    @Published var runSummary: String = "Aucun traitement exécuté."

    @Published var alertInfo: AlertInfo?

    let profiles = ConversionProfile.all

    private let settingsStore: SettingsStore
    private let libreOfficeLocator: LibreOfficeLocator
    private let coordinator: ConversionCoordinator

    private var runTask: Task<Void, Never>?

    init(
        settingsStore: SettingsStore = SettingsStore(),
        libreOfficeLocator: LibreOfficeLocator = LibreOfficeLocator(),
        coordinator: ConversionCoordinator = ConversionCoordinator()
    ) {
        self.settingsStore = settingsStore
        self.libreOfficeLocator = libreOfficeLocator
        self.coordinator = coordinator

        loadSettings()
        refreshLibreOfficeStatus()
    }

    var selectedProfile: ConversionProfile? {
        ConversionProfile.byID(selectedProfileID)
    }

    var sourcePathText: String {
        sourceFolderURL?.path ?? "Aucun dossier source"
    }

    var outputPathText: String {
        outputFolderURL?.path ?? "Aucun dossier de sortie"
    }

    var canAnalyze: Bool {
        !isRunning && sourceFolderURL != nil && selectedProfile != nil && (!useSeparateOutputFolder || outputFolderURL != nil)
    }

    var canStartConversion: Bool {
        canAnalyze && (dryRunOnly || libreOfficeFound)
    }

    var activeOutputFolder: URL? {
        if useSeparateOutputFolder {
            return outputFolderURL
        }
        return sourceFolderURL
    }

    func chooseSourceFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choisir un dossier source"
        panel.message = "Sélectionnez le dossier contenant les fichiers à convertir."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            sourceFolderURL = panel.url
        }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choisir un dossier de sortie"
        panel.message = "Sélectionnez le dossier où seront créés les fichiers convertis."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            outputFolderURL = panel.url
        }
    }

    func refreshLibreOfficeStatus() {
        let preferred = libreOfficePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = libreOfficeLocator.locate(preferredPath: preferred.isEmpty ? nil : preferred)

        libreOfficeFound = info.isFound
        libreOfficeVersion = info.version
        libreOfficeMessage = info.message

        if info.isFound {
            libreOfficePath = info.executablePath
        }
    }

    func testLibreOfficePath() {
        let path = libreOfficePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            alertInfo = AlertInfo(
                title: "Chemin manquant",
                message: "Saisissez un chemin vers soffice avant le test."
            )
            return
        }

        let info = libreOfficeLocator.test(path: path)
        libreOfficeFound = info.isFound
        libreOfficeVersion = info.version
        libreOfficeMessage = info.message

        if info.isFound {
            alertInfo = AlertInfo(
                title: "LibreOffice détecté",
                message: "Version: \(info.version.isEmpty ? "inconnue" : info.version)"
            )
        } else {
            alertInfo = AlertInfo(
                title: "LibreOffice introuvable",
                message: "Le chemin indiqué n'est pas exécutable."
            )
        }
    }

    func analyze() {
        do {
            let options = try buildOptions()
            startNewRun(initialMessage: "Analyse en cours")

            runTask = Task {
                do {
                    let computedStats = try await coordinator.analyze(
                        options: options,
                        eventHandler: eventHandler()
                    )
                    self.stats = computedStats
                    finishRun(operationLabel: "Analyse")
                } catch {
                    handleRunError(error, operationLabel: "Analyse")
                    finishRun(operationLabel: "Analyse")
                }
            }
        } catch {
            alertInfo = AlertInfo(title: "Analyse impossible", message: error.localizedDescription)
        }
    }

    func startConversion() {
        do {
            let options = try buildOptions()

            if !options.dryRun && !libreOfficeFound {
                throw MuniConvertError.libreOfficeNotFound
            }

            let executableURL: URL?
            if options.dryRun {
                executableURL = nil
            } else {
                executableURL = URL(fileURLWithPath: libreOfficePath)
            }

            startNewRun(initialMessage: options.dryRun ? "Simulation en cours" : "Conversion en cours")
            let operationLabel = options.dryRun ? "Simulation" : "Conversion"

            runTask = Task {
                do {
                    let computedStats = try await coordinator.convert(
                        options: options,
                        libreOfficeExecutable: executableURL,
                        eventHandler: eventHandler()
                    )
                    self.stats = computedStats
                    finishRun(operationLabel: operationLabel)
                } catch {
                    handleRunError(error, operationLabel: operationLabel)
                    finishRun(operationLabel: operationLabel)
                }
            }
        } catch {
            alertInfo = AlertInfo(title: "Conversion impossible", message: error.localizedDescription)
        }
    }

    func stopCurrentRun() {
        guard isRunning else {
            return
        }

        progressMessage = "Annulation en cours..."
        runSummary = "Annulation demandée..."

        runTask?.cancel()
        Task {
            await coordinator.cancelCurrentRun()
        }
    }

    func clearLogs() {
        logs.removeAll()
        stats = ConversionStats()
        progress = 0
        progressMessage = "Prêt"
        runState = .idle
        runSummary = "Aucun traitement exécuté."
    }

    func exportLogs() {
        guard !logs.isEmpty else {
            alertInfo = AlertInfo(title: "Journal vide", message: "Aucune entrée à exporter.")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Exporter le journal"
        panel.nameFieldStringValue = defaultLogFileName()
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            try buildLogText().write(to: destinationURL, atomically: true, encoding: .utf8)
            alertInfo = AlertInfo(
                title: "Export réussi",
                message: "Journal exporté vers:\n\(destinationURL.path)"
            )
        } catch {
            alertInfo = AlertInfo(
                title: "Export échoué",
                message: error.localizedDescription
            )
        }
    }

    func openOutputFolderInFinder() {
        guard let folder = activeOutputFolder else {
            alertInfo = AlertInfo(
                title: "Aucun dossier",
                message: "Sélectionnez un dossier source ou un dossier de sortie."
            )
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    private func startNewRun(initialMessage: String) {
        runTask?.cancel()
        logs.removeAll()
        stats = ConversionStats()
        progress = 0
        progressMessage = initialMessage
        isRunning = true
        runState = .running
        runSummary = "Traitement en cours..."
    }

    private func finishRun(operationLabel: String) {
        isRunning = false
        if progress < 1 {
            progress = 1
        }

        if runState == .running {
            runState = .completed
        }

        switch runState {
        case .completed:
            progressMessage = "\(operationLabel) terminée"
            runSummary = buildSummary(prefix: "\(operationLabel) terminée")
        case .cancelled:
            progressMessage = "\(operationLabel) annulée"
            runSummary = buildSummary(prefix: "\(operationLabel) annulée")
        case .failed:
            if runSummary == "Traitement en cours..." || runSummary == "Aucun traitement exécuté." {
                runSummary = "\(operationLabel) interrompue."
            }
            progressMessage = "\(operationLabel) en erreur"
        case .idle:
            progressMessage = "Prêt"
            runSummary = "Aucun traitement exécuté."
        case .running:
            break
        }

        runTask = nil
    }

    private func handleRunError(_ error: Error, operationLabel: String) {
        if let mcError = error as? MuniConvertError, case .cancelled = mcError {
            runState = .cancelled
            runSummary = buildSummary(prefix: "\(operationLabel) annulée")
            return
        }

        runState = .failed
        runSummary = "\(operationLabel) interrompue: \(error.localizedDescription)"
        alertInfo = AlertInfo(title: "Erreur", message: error.localizedDescription)
    }

    private func buildOptions() throws -> ConversionOptions {
        guard let sourceFolderURL else {
            throw MuniConvertError.sourceFolderInvalid("Aucun dossier source")
        }

        guard let selectedProfile else {
            throw MuniConvertError.invalidProfile
        }

        if useSeparateOutputFolder && outputFolderURL == nil {
            throw MuniConvertError.outputFolderInvalid("Aucun dossier de sortie")
        }

        return ConversionOptions(
            sourceFolder: sourceFolderURL,
            outputFolder: outputFolderURL,
            useSeparateOutputFolder: useSeparateOutputFolder,
            preserveRelativeStructure: preserveRelativeStructure,
            includeSubdirectories: includeSubdirectories,
            dryRun: dryRunOnly,
            ignoreHiddenFiles: ignoreHiddenFiles,
            collisionPolicy: collisionPolicy,
            profile: selectedProfile
        )
    }

    private func eventHandler() -> ConversionEventHandler {
        return { [weak self] event in
            await self?.handleEvent(event)
        }
    }

    @MainActor
    private func handleEvent(_ event: ConversionEvent) {
        switch event {
        case .log(let entry):
            logs.append(entry)
            stats = deriveStatsFromLogs()
        case .progress(let value, let message):
            progress = min(max(value, 0), 1)
            progressMessage = message
        }
    }

    private func buildSummary(prefix: String) -> String {
        "\(prefix) — Scannés: \(stats.totalScanned), Correspondants: \(stats.totalMatched), Convertis: \(stats.converted), Simulation: \(stats.dryRun), Ignorés: \(stats.ignored), Ignorés (cible existe): \(stats.skippedExisting), Erreurs: \(stats.errors)."
    }

    private func deriveStatsFromLogs() -> ConversionStats {
        var derived = ConversionStats()
        derived.totalMatched = logs.reduce(0) { $0 + ($1.status == .matched ? 1 : 0) }
        derived.ignored = logs.reduce(0) { $0 + ($1.status == .ignored ? 1 : 0) }
        derived.converted = logs.reduce(0) { $0 + ($1.status == .converted ? 1 : 0) }
        derived.errors = logs.reduce(0) { $0 + ($1.status == .failed ? 1 : 0) }
        derived.skippedExisting = logs.reduce(0) { $0 + ($1.status == .skippedExisting ? 1 : 0) }
        derived.dryRun = logs.reduce(0) { $0 + ($1.status == .dryRun ? 1 : 0) }
        derived.totalScanned = derived.totalMatched + derived.ignored
        return derived
    }

    private func loadSettings() {
        let stored = settingsStore.load()

        sourceFolderURL = stored.sourcePath.map { URL(fileURLWithPath: $0) }
        outputFolderURL = stored.outputPath.map { URL(fileURLWithPath: $0) }
        includeSubdirectories = stored.includeSubdirectories
        useSeparateOutputFolder = stored.useSeparateOutputFolder
        preserveRelativeStructure = stored.preserveRelativeStructure
        dryRunOnly = stored.dryRun
        ignoreHiddenFiles = stored.ignoreHiddenFiles
        selectedProfileID = stored.selectedProfileID
        collisionPolicy = CollisionPolicy(rawValue: stored.collisionPolicy) ?? .skipExisting
        libreOfficePath = stored.libreOfficePath
    }

    private func persistSettings() {
        let settings = StoredSettings(
            sourcePath: sourceFolderURL?.path,
            outputPath: outputFolderURL?.path,
            includeSubdirectories: includeSubdirectories,
            useSeparateOutputFolder: useSeparateOutputFolder,
            preserveRelativeStructure: preserveRelativeStructure,
            dryRun: dryRunOnly,
            ignoreHiddenFiles: ignoreHiddenFiles,
            selectedProfileID: selectedProfileID,
            collisionPolicy: collisionPolicy.rawValue,
            libreOfficePath: libreOfficePath
        )

        settingsStore.save(settings)
    }

    private func buildLogText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        var lines: [String] = []
        lines.append("MuniConvert - Journal")
        lines.append("Date export: \(formatter.string(from: Date()))")
        lines.append(stats.summaryLine)
        lines.append("")

        for entry in logs {
            let date = formatter.string(from: entry.date)
            let line = "[\(date)] [\(entry.status.displayName)] source=\(entry.sourcePath) output=\(entry.outputPath) message=\(entry.message)"
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    private func defaultLogFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "MuniConvert-log-\(formatter.string(from: Date())).txt"
    }
}
