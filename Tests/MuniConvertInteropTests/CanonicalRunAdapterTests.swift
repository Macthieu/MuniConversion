import Foundation
import OrchivisteKitContracts
import Testing
@testable import MuniConvertInterop

struct CanonicalRunAdapterTests {
    @Test
    func cliArgumentsParseRunRequestResult() throws {
        let parsed = try CanonicalCLIArguments.parse([
            "run",
            "--request", "/tmp/request.json",
            "--result", "/tmp/result.json"
        ])

        #expect(parsed.requestPath == "/tmp/request.json")
        #expect(parsed.resultPath == "/tmp/result.json")
    }

    @Test
    func cliArgumentsRejectMissingResult() throws {
        do {
            _ = try CanonicalCLIArguments.parse([
                "run",
                "--request", "/tmp/request.json"
            ])
            Issue.record("Expected parser failure for missing --result")
        } catch let error as CanonicalCLIArgumentsError {
            switch error {
            case .usage(let message):
                #expect(message.contains("--result"))
            }
        }
    }

    @Test
    func canonicalConvertRequiresExplicitConfirmation() async throws {
        let temp = try TempInteropDirectory()
        _ = try temp.createFile("source.doc")

        let request = ToolRequest(
            requestID: "req-confirm",
            tool: "MuniConversion",
            action: "convert",
            inputArtifacts: [],
            parameters: [
                "source_path": .string(temp.url.path),
                "profile_id": .string("doc_to_pdf"),
                "dry_run": .bool(false),
                "confirm_convert": .bool(false)
            ]
        )

        let result = await CanonicalRunAdapter.execute(request: request)

        #expect(result.status == .failed)
        #expect(result.errors.contains { $0.code == "EXPLICIT_CONFIRMATION_REQUIRED" })
    }

    @Test
    func canonicalAnalyzeProducesSucceededResult() async throws {
        let temp = try TempInteropDirectory()
        _ = try temp.createFile("source.doc")

        let request = ToolRequest(
            requestID: "req-analyze",
            tool: "MuniConversion",
            action: "analyze",
            inputArtifacts: [],
            parameters: [
                "source_path": .string(temp.url.path),
                "profile_id": .string("doc_to_pdf")
            ]
        )

        let result = await CanonicalRunAdapter.execute(request: request)

        #expect(result.status == .succeeded)
        #expect(result.errors.isEmpty)
        #expect(result.progressEvents.contains { $0.status == .running })
        #expect(result.progressEvents.last?.status == .succeeded)
    }
}

private final class TempInteropDirectory {
    let url: URL
    private let fileManager = FileManager.default

    init() throws {
        let base = fileManager.temporaryDirectory
        url = base.appendingPathComponent("MuniConvertInteropTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: url)
    }

    @discardableResult
    func createFile(_ name: String, contents: String = "sample") throws -> URL {
        let fileURL = url.appendingPathComponent(name)
        try contents.data(using: .utf8)?.write(to: fileURL)
        return fileURL
    }
}
