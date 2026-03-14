// SPDX-License-Identifier: GPL-3.0-only

import Foundation

public enum ConversionCoreAction: String, Sendable {
    case analyze
    case convert
}

public enum ConversionCoreError: Error, Sendable {
    case missingParameter(String)
    case invalidParameter(String, String)
    case invalidProfile(String)
    case explicitConfirmationRequired
    case sourceFolderInvalid(String)
    case outputFolderInvalid(String)
    case libreOfficeNotFound
    case conversionFailed(String)
    case processLaunchFailed(String)
    case cancelled
    case runtime(String)
}

public struct ConversionCoreRequest: Sendable {
    public let action: ConversionCoreAction
    public let sourcePath: String
    public let profileID: String
    public let outputPath: String?
    public let includeSubdirectories: Bool
    public let preserveRelativeStructure: Bool
    public let ignoreHiddenFiles: Bool
    public let collisionPolicy: String
    public let dryRun: Bool
    public let confirmConvert: Bool
    public let libreOfficePath: String?

    public init(
        action: ConversionCoreAction,
        sourcePath: String,
        profileID: String,
        outputPath: String? = nil,
        includeSubdirectories: Bool = false,
        preserveRelativeStructure: Bool = false,
        ignoreHiddenFiles: Bool = true,
        collisionPolicy: String = "skip_existing",
        dryRun: Bool = true,
        confirmConvert: Bool = false,
        libreOfficePath: String? = nil
    ) {
        self.action = action
        self.sourcePath = sourcePath
        self.profileID = profileID
        self.outputPath = outputPath
        self.includeSubdirectories = includeSubdirectories
        self.preserveRelativeStructure = preserveRelativeStructure
        self.ignoreHiddenFiles = ignoreHiddenFiles
        self.collisionPolicy = collisionPolicy
        self.dryRun = dryRun
        self.confirmConvert = confirmConvert
        self.libreOfficePath = libreOfficePath
    }
}

public struct ConversionCoreProgress: Sendable {
    public let fractionCompleted: Double
    public let message: String
    public let occurredAt: String

    public init(fractionCompleted: Double, message: String, occurredAt: String) {
        self.fractionCompleted = fractionCompleted
        self.message = message
        self.occurredAt = occurredAt
    }
}

public enum ConversionCoreLogStatus: String, Sendable {
    case matched
    case ignored
    case converted
    case failed
    case skippedExisting = "skipped_existing"
    case dryRun = "dry_run"
}

public struct ConversionCoreLogEntry: Sendable {
    public let sourcePath: String
    public let status: ConversionCoreLogStatus
    public let outputPath: String
    public let message: String
    public let occurredAt: String

    public init(sourcePath: String, status: ConversionCoreLogStatus, outputPath: String, message: String, occurredAt: String) {
        self.sourcePath = sourcePath
        self.status = status
        self.outputPath = outputPath
        self.message = message
        self.occurredAt = occurredAt
    }
}

public struct ConversionCoreStats: Sendable {
    public let totalScanned: Int
    public let totalMatched: Int
    public let converted: Int
    public let ignored: Int
    public let errors: Int
    public let skippedExisting: Int
    public let dryRun: Int

    public init(
        totalScanned: Int,
        totalMatched: Int,
        converted: Int,
        ignored: Int,
        errors: Int,
        skippedExisting: Int,
        dryRun: Int
    ) {
        self.totalScanned = totalScanned
        self.totalMatched = totalMatched
        self.converted = converted
        self.ignored = ignored
        self.errors = errors
        self.skippedExisting = skippedExisting
        self.dryRun = dryRun
    }
}

public struct ConversionCoreResult: Sendable {
    public let action: ConversionCoreAction
    public let sourcePath: String
    public let outputRootPath: String
    public let dryRun: Bool
    public let stats: ConversionCoreStats
    public let logs: [ConversionCoreLogEntry]

    public init(
        action: ConversionCoreAction,
        sourcePath: String,
        outputRootPath: String,
        dryRun: Bool,
        stats: ConversionCoreStats,
        logs: [ConversionCoreLogEntry]
    ) {
        self.action = action
        self.sourcePath = sourcePath
        self.outputRootPath = outputRootPath
        self.dryRun = dryRun
        self.stats = stats
        self.logs = logs
    }
}

private actor ConversionCoreEventCollector {
    private var entries: [ConversionCoreLogEntry] = []

    func append(_ entry: LogEntry) {
        entries.append(
            ConversionCoreLogEntry(
                sourcePath: entry.sourcePath,
                status: mapStatus(entry.status),
                outputPath: entry.outputPath,
                message: entry.message,
                occurredAt: isoTimestamp(entry.date)
            )
        )
    }

    func snapshot() -> [ConversionCoreLogEntry] {
        entries
    }

    private func mapStatus(_ status: LogStatus) -> ConversionCoreLogStatus {
        switch status {
        case .matched:
            return .matched
        case .ignored:
            return .ignored
        case .converted:
            return .converted
        case .failed:
            return .failed
        case .skippedExisting:
            return .skippedExisting
        case .dryRun:
            return .dryRun
        }
    }

    private func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

public final class ConversionCoreService {
    private let coordinator: ConversionCoordinator
    private let libreOfficeLocator: LibreOfficeLocator

    public init() {
        self.coordinator = ConversionCoordinator()
        self.libreOfficeLocator = LibreOfficeLocator()
    }

    public func execute(
        _ request: ConversionCoreRequest,
        progressHandler: (@Sendable (ConversionCoreProgress) async -> Void)? = nil
    ) async throws -> ConversionCoreResult {
        let sourcePath = request.sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if sourcePath.isEmpty {
            throw ConversionCoreError.missingParameter("source_path")
        }

        guard let profile = ConversionProfile.byID(request.profileID) else {
            throw ConversionCoreError.invalidProfile(request.profileID)
        }

        let effectiveDryRun = request.action == .analyze ? true : request.dryRun
        if request.action == .convert && !effectiveDryRun && !request.confirmConvert {
            throw ConversionCoreError.explicitConfirmationRequired
        }

        let outputPath = request.outputPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSeparateOutput = outputPath?.isEmpty == false
        let outputURL = hasSeparateOutput ? URL(fileURLWithPath: outputPath!) : nil
        let collisionPolicy = try parseCollisionPolicy(rawValue: request.collisionPolicy)

        let options = ConversionOptions(
            sourceFolder: URL(fileURLWithPath: sourcePath),
            outputFolder: outputURL,
            useSeparateOutputFolder: hasSeparateOutput,
            preserveRelativeStructure: request.preserveRelativeStructure,
            includeSubdirectories: request.includeSubdirectories,
            dryRun: effectiveDryRun,
            ignoreHiddenFiles: request.ignoreHiddenFiles,
            collisionPolicy: collisionPolicy,
            profile: profile
        )

        let collector = ConversionCoreEventCollector()
        let eventHandler: ConversionEventHandler = { event in
            switch event {
            case .progress(let value, let message):
                if let progressHandler {
                    await progressHandler(
                        ConversionCoreProgress(
                            fractionCompleted: min(max(value, 0), 1),
                            message: message,
                            occurredAt: Self.isoTimestamp(Date())
                        )
                    )
                }
            case .log(let entry):
                await collector.append(entry)
            }
        }

        do {
            let stats: ConversionStats
            switch request.action {
            case .analyze:
                stats = try await coordinator.analyze(options: options, eventHandler: eventHandler)
            case .convert:
                let executable: URL?
                if effectiveDryRun {
                    executable = nil
                } else {
                    let preferredPath = request.libreOfficePath?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let info = libreOfficeLocator.locate(preferredPath: preferredPath?.isEmpty == true ? nil : preferredPath)
                    if !info.isFound {
                        throw ConversionCoreError.libreOfficeNotFound
                    }
                    executable = URL(fileURLWithPath: info.executablePath)
                }

                stats = try await coordinator.convert(
                    options: options,
                    libreOfficeExecutable: executable,
                    eventHandler: eventHandler
                )
            }

            let logs = await collector.snapshot()
            let outputRootPath = outputURL?.path ?? sourcePath
            return ConversionCoreResult(
                action: request.action,
                sourcePath: sourcePath,
                outputRootPath: outputRootPath,
                dryRun: effectiveDryRun,
                stats: ConversionCoreStats(
                    totalScanned: stats.totalScanned,
                    totalMatched: stats.totalMatched,
                    converted: stats.converted,
                    ignored: stats.ignored,
                    errors: stats.errors,
                    skippedExisting: stats.skippedExisting,
                    dryRun: stats.dryRun
                ),
                logs: logs
            )
        } catch let error as ConversionCoreError {
            throw error
        } catch let error as MuniConvertError {
            throw mapError(error)
        } catch {
            throw ConversionCoreError.runtime(error.localizedDescription)
        }
    }

    private func parseCollisionPolicy(rawValue: String) throws -> CollisionPolicy {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")

        switch normalized {
        case "", "skip_existing", "skipexisting":
            return .skipExisting
        case "overwrite":
            return .overwrite
        case "rename_with_suffix", "renamewithsuffix":
            return .renameWithSuffix
        default:
            throw ConversionCoreError.invalidParameter(
                "collision_policy",
                "expected skip_existing|overwrite|rename_with_suffix"
            )
        }
    }

    private func mapError(_ error: MuniConvertError) -> ConversionCoreError {
        switch error {
        case .libreOfficeNotFound:
            return .libreOfficeNotFound
        case .sourceFolderInvalid(let path):
            return .sourceFolderInvalid(path)
        case .outputFolderInvalid(let path):
            return .outputFolderInvalid(path)
        case .fileInaccessible(let path):
            return .runtime("Fichier inaccessible: \(path)")
        case .conversionFailed(let details):
            return .conversionFailed(details)
        case .nameCollision(let path):
            return .conversionFailed("Collision de nom pour \(path)")
        case .invalidProfile:
            return .invalidProfile("unknown")
        case .processLaunchFailed(let details):
            return .processLaunchFailed(details)
        case .cancelled:
            return .cancelled
        }
    }

    private static func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
