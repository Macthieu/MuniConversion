// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import MuniConvertCore
import OrchivisteKitContracts

public enum CanonicalCLIArgumentsError: Error {
    case usage(String)
}

public struct CanonicalCLIArguments: Sendable {
    public let requestPath: String
    public let resultPath: String

    public static func parse(_ args: [String]) throws -> CanonicalCLIArguments {
        guard args.first == "run" else {
            throw CanonicalCLIArgumentsError.usage("Commande attendue: run")
        }

        guard let requestPath = optionValue("--request", in: args) else {
            throw CanonicalCLIArgumentsError.usage("--request est obligatoire")
        }

        guard let resultPath = optionValue("--result", in: args) else {
            throw CanonicalCLIArgumentsError.usage("--result est obligatoire")
        }

        return CanonicalCLIArguments(requestPath: requestPath, resultPath: resultPath)
    }

    private static func optionValue(_ option: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: option), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }
}

public enum CanonicalRunAdapterError: Error {
    case unsupportedAction(String)
    case missingParameter(String)
    case invalidParameter(String, String)

    var toolError: ToolError {
        switch self {
        case .unsupportedAction(let action):
            return ToolError(
                code: "UNSUPPORTED_ACTION",
                message: "Unsupported action: \(action)",
                retryable: false
            )
        case .missingParameter(let parameter):
            return ToolError(
                code: "MISSING_PARAMETER",
                message: "Missing required parameter: \(parameter)",
                retryable: false
            )
        case .invalidParameter(let parameter, let reason):
            return ToolError(
                code: "INVALID_PARAMETER",
                message: "Invalid parameter \(parameter): \(reason)",
                retryable: false
            )
        }
    }
}

private actor ProgressAccumulator {
    private let requestID: String
    private var events: [ProgressEvent]

    init(requestID: String, startedAt: String) {
        self.requestID = requestID
        self.events = [
            ProgressEvent(
                requestID: requestID,
                status: .running,
                stage: "accepted",
                percent: 0,
                message: "Request accepted.",
                occurredAt: startedAt
            )
        ]
    }

    func append(progress: ConversionCoreProgress) {
        let clampedPercent = min(max(Int((progress.fractionCompleted * 100).rounded()), 0), 100)
        events.append(
            ProgressEvent(
                requestID: requestID,
                status: .running,
                stage: "processing",
                percent: clampedPercent,
                message: progress.message,
                occurredAt: progress.occurredAt
            )
        )
    }

    func complete(status: ToolStatus, summary: String, finishedAt: String) {
        events.append(
            ProgressEvent(
                requestID: requestID,
                status: status,
                stage: "completed",
                percent: 100,
                message: summary,
                occurredAt: finishedAt
            )
        )
    }

    func snapshot() -> [ProgressEvent] {
        events
    }
}

private struct ParsedCanonicalRequest {
    let action: ConversionCoreAction
    let coreRequest: ConversionCoreRequest
}

public enum CanonicalRunAdapter {
    public static func execute(
        request: ToolRequest,
        service: ConversionCoreService = ConversionCoreService()
    ) async -> ToolResult {
        let startedAt = isoTimestamp()
        let progress = ProgressAccumulator(requestID: request.requestID, startedAt: startedAt)

        do {
            let parsed = try parseRequest(request)
            let coreResult = try await service.execute(
                parsed.coreRequest,
                progressHandler: { progressEvent in
                    await progress.append(progress: progressEvent)
                }
            )

            let finishedAt = isoTimestamp()
            let finalStatus: ToolStatus = coreResult.stats.errors > 0 ? .needsReview : .succeeded
            let summary = buildSummary(action: parsed.action, stats: coreResult.stats, dryRun: coreResult.dryRun)
            await progress.complete(status: finalStatus, summary: summary, finishedAt: finishedAt)

            let reviewErrors = toolErrorsFromFailedLogs(coreResult.logs)
            let errors = finalStatus == .needsReview ? reviewErrors : []

            return ToolResult(
                schemaVersion: request.schemaVersion,
                requestID: request.requestID,
                tool: request.tool,
                status: finalStatus,
                startedAt: startedAt,
                finishedAt: finishedAt,
                progressEvents: await progress.snapshot(),
                outputArtifacts: buildArtifacts(action: parsed.action, result: coreResult),
                errors: errors,
                summary: summary,
                metadata: buildMetadata(parsed: parsed, result: coreResult)
            )
        } catch let adapterError as CanonicalRunAdapterError {
            let finishedAt = isoTimestamp()
            let summary = "Canonical request validation failed."
            await progress.complete(status: .failed, summary: summary, finishedAt: finishedAt)
            return ToolResult(
                schemaVersion: request.schemaVersion,
                requestID: request.requestID,
                tool: request.tool,
                status: .failed,
                startedAt: startedAt,
                finishedAt: finishedAt,
                progressEvents: await progress.snapshot(),
                outputArtifacts: [],
                errors: [adapterError.toolError],
                summary: summary,
                metadata: ["action": .string(request.action)]
            )
        } catch let coreError as ConversionCoreError {
            let finishedAt = isoTimestamp()
            let mapped = mapCoreError(coreError)
            let summary = mapped.status == .cancelled ? "Operation cancelled." : "Core execution failed."
            await progress.complete(status: mapped.status, summary: summary, finishedAt: finishedAt)
            return ToolResult(
                schemaVersion: request.schemaVersion,
                requestID: request.requestID,
                tool: request.tool,
                status: mapped.status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                progressEvents: await progress.snapshot(),
                outputArtifacts: [],
                errors: [mapped.error],
                summary: summary,
                metadata: ["action": .string(request.action)]
            )
        } catch {
            let finishedAt = isoTimestamp()
            let summary = "Unexpected runtime failure."
            await progress.complete(status: .failed, summary: summary, finishedAt: finishedAt)
            return ToolResult(
                schemaVersion: request.schemaVersion,
                requestID: request.requestID,
                tool: request.tool,
                status: .failed,
                startedAt: startedAt,
                finishedAt: finishedAt,
                progressEvents: await progress.snapshot(),
                outputArtifacts: [],
                errors: [
                    ToolError(
                        code: "RUNTIME_ERROR",
                        message: error.localizedDescription,
                        retryable: false
                    )
                ],
                summary: summary,
                metadata: ["action": .string(request.action)]
            )
        }
    }

    private static func parseRequest(_ request: ToolRequest) throws -> ParsedCanonicalRequest {
        let action = try parseAction(request.action)
        let sourcePath = try resolveSourcePath(in: request)
        let profileID = try requiredStringParameter("profile_id", in: request)
        let outputPath = try optionalStringParameter("output_path", in: request)
        let includeSubdirectories = try optionalBoolParameter("include_subdirectories", in: request) ?? false
        let preserveRelativeStructure = try optionalBoolParameter("preserve_relative_structure", in: request) ?? false
        let ignoreHiddenFiles = try optionalBoolParameter("ignore_hidden_files", in: request) ?? true
        let collisionPolicy = try optionalStringParameter("collision_policy", in: request) ?? "skip_existing"
        let dryRun = try optionalBoolParameter("dry_run", in: request) ?? true
        let confirmConvert = try optionalBoolParameter("confirm_convert", in: request) ?? false
        let libreOfficePath = try optionalStringParameter("libreoffice_path", in: request)

        let coreRequest = ConversionCoreRequest(
            action: action,
            sourcePath: sourcePath,
            profileID: profileID,
            outputPath: outputPath,
            includeSubdirectories: includeSubdirectories,
            preserveRelativeStructure: preserveRelativeStructure,
            ignoreHiddenFiles: ignoreHiddenFiles,
            collisionPolicy: collisionPolicy,
            dryRun: dryRun,
            confirmConvert: confirmConvert,
            libreOfficePath: libreOfficePath
        )

        return ParsedCanonicalRequest(action: action, coreRequest: coreRequest)
    }

    private static func parseAction(_ rawAction: String) throws -> ConversionCoreAction {
        let normalized = rawAction
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        switch normalized {
        case "analyze":
            return .analyze
        case "convert", "run":
            return .convert
        default:
            throw CanonicalRunAdapterError.unsupportedAction(rawAction)
        }
    }

    private static func resolveSourcePath(in request: ToolRequest) throws -> String {
        if let sourcePath = try optionalStringParameter("source_path", in: request) {
            return sourcePath
        }

        if let inputArtifact = request.inputArtifacts.first(where: { $0.kind == .input }) {
            return resolvePathFromURIOrPath(inputArtifact.uri)
        }

        throw CanonicalRunAdapterError.missingParameter("source_path")
    }

    private static func requiredStringParameter(_ key: String, in request: ToolRequest) throws -> String {
        guard let value = try optionalStringParameter(key, in: request) else {
            throw CanonicalRunAdapterError.missingParameter(key)
        }
        return value
    }

    private static func optionalStringParameter(_ key: String, in request: ToolRequest) throws -> String? {
        guard let value = request.parameters[key] else {
            return nil
        }

        switch value {
        case .string(let stringValue):
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return nil
            }
            return resolvePathFromURIOrPath(trimmed)
        default:
            throw CanonicalRunAdapterError.invalidParameter(key, "expected string")
        }
    }

    private static func optionalBoolParameter(_ key: String, in request: ToolRequest) throws -> Bool? {
        guard let value = request.parameters[key] else {
            return nil
        }

        switch value {
        case .bool(let boolValue):
            return boolValue
        default:
            throw CanonicalRunAdapterError.invalidParameter(key, "expected boolean")
        }
    }

    private static func buildSummary(action: ConversionCoreAction, stats: ConversionCoreStats, dryRun: Bool) -> String {
        switch action {
        case .analyze:
            return "Analysis completed: scanned \(stats.totalScanned), matched \(stats.totalMatched), ignored \(stats.ignored)."
        case .convert:
            if dryRun {
                return "Dry-run completed: matched \(stats.totalMatched), simulated \(stats.dryRun), skipped \(stats.skippedExisting), errors \(stats.errors)."
            }
            return "Conversion completed: converted \(stats.converted), skipped \(stats.skippedExisting), errors \(stats.errors)."
        }
    }

    private static func buildMetadata(parsed: ParsedCanonicalRequest, result: ConversionCoreResult) -> [String: JSONValue] {
        [
            "action": .string(parsed.action.rawValue),
            "source_path": .string(result.sourcePath),
            "output_root_path": .string(result.outputRootPath),
            "dry_run": .bool(result.dryRun),
            "profile_id": .string(parsed.coreRequest.profileID),
            "include_subdirectories": .bool(parsed.coreRequest.includeSubdirectories),
            "ignore_hidden_files": .bool(parsed.coreRequest.ignoreHiddenFiles),
            "collision_policy": .string(parsed.coreRequest.collisionPolicy),
            "total_scanned": .number(Double(result.stats.totalScanned)),
            "total_matched": .number(Double(result.stats.totalMatched)),
            "converted": .number(Double(result.stats.converted)),
            "simulated": .number(Double(result.stats.dryRun)),
            "ignored": .number(Double(result.stats.ignored)),
            "skipped_existing": .number(Double(result.stats.skippedExisting)),
            "errors": .number(Double(result.stats.errors))
        ]
    }

    private static func buildArtifacts(action: ConversionCoreAction, result: ConversionCoreResult) -> [ArtifactDescriptor] {
        guard action == .convert, !result.dryRun else {
            return []
        }

        return [
            ArtifactDescriptor(
                id: "output_root",
                kind: .output,
                uri: fileURI(forPath: result.outputRootPath),
                mediaType: "inode/directory"
            )
        ]
    }

    private static func toolErrorsFromFailedLogs(_ logs: [ConversionCoreLogEntry]) -> [ToolError] {
        logs.enumerated().compactMap { index, log in
            guard log.status == .failed else {
                return nil
            }
            return ToolError(
                code: "CONVERSION_FAILED",
                message: log.message,
                details: [
                    "index": .number(Double(index)),
                    "source_path": .string(log.sourcePath),
                    "output_path": .string(log.outputPath)
                ],
                retryable: false
            )
        }
    }

    private static func mapCoreError(_ error: ConversionCoreError) -> (status: ToolStatus, error: ToolError) {
        switch error {
        case .missingParameter(let parameter):
            return (.failed, ToolError(code: "MISSING_PARAMETER", message: "Missing required parameter: \(parameter)", retryable: false))
        case .invalidParameter(let parameter, let reason):
            return (.failed, ToolError(code: "INVALID_PARAMETER", message: "Invalid parameter \(parameter): \(reason)", retryable: false))
        case .invalidProfile(let profileID):
            return (.failed, ToolError(code: "INVALID_PROFILE", message: "Unknown conversion profile: \(profileID)", retryable: false))
        case .explicitConfirmationRequired:
            return (.failed, ToolError(code: "EXPLICIT_CONFIRMATION_REQUIRED", message: "Real conversion requires confirm_convert=true and dry_run=false.", retryable: false))
        case .sourceFolderInvalid(let path):
            return (.failed, ToolError(code: "SOURCE_FOLDER_INVALID", message: "Invalid source folder: \(path)", retryable: false))
        case .outputFolderInvalid(let path):
            return (.failed, ToolError(code: "OUTPUT_FOLDER_INVALID", message: "Invalid output folder: \(path)", retryable: false))
        case .libreOfficeNotFound:
            return (.failed, ToolError(code: "LIBREOFFICE_NOT_FOUND", message: "LibreOffice executable not found.", retryable: false))
        case .conversionFailed(let details):
            return (.failed, ToolError(code: "CONVERSION_FAILED", message: details, retryable: false))
        case .processLaunchFailed(let details):
            return (.failed, ToolError(code: "PROCESS_LAUNCH_FAILED", message: details, retryable: false))
        case .cancelled:
            return (.cancelled, ToolError(code: "CANCELLED", message: "Operation cancelled.", retryable: false))
        case .runtime(let reason):
            return (.failed, ToolError(code: "RUNTIME_ERROR", message: reason, retryable: false))
        }
    }

    private static func resolvePathFromURIOrPath(_ candidate: String) -> String {
        guard let url = URL(string: candidate), url.isFileURL else {
            return candidate
        }
        return url.path
    }

    private static func fileURI(forPath path: String) -> String {
        URL(fileURLWithPath: path).absoluteString
    }

    private static func isoTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date())
    }
}
