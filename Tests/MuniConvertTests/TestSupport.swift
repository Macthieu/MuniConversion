import Foundation
@testable import MuniConvertCore

final class TempDirectory {
    let url: URL
    private let fileManager = FileManager.default

    init() throws {
        let base = fileManager.temporaryDirectory
        url = base.appendingPathComponent("MuniConvertTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: url)
    }

    @discardableResult
    func createDirectory(_ relativePath: String) throws -> URL {
        let directoryURL = url.appendingPathComponent(relativePath, isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    @discardableResult
    func createFile(_ relativePath: String, contents: String = "sample") throws -> URL {
        let fileURL = url.appendingPathComponent(relativePath)
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try contents.data(using: .utf8)?.write(to: fileURL)
        return fileURL
    }
}

func makeOptions(
    source: URL,
    output: URL? = nil,
    useSeparateOutputFolder: Bool = false,
    preserveRelativeStructure: Bool = false,
    includeSubdirectories: Bool = false,
    dryRun: Bool = false,
    ignoreHiddenFiles: Bool = true,
    collisionPolicy: CollisionPolicy = .skipExisting,
    profileID: String = "doc_to_pdf"
) -> ConversionOptions {
    guard let profile = ConversionProfile.byID(profileID) else {
        fatalError("Profil \(profileID) absent")
    }

    return ConversionOptions(
        sourceFolder: source,
        outputFolder: output,
        useSeparateOutputFolder: useSeparateOutputFolder,
        preserveRelativeStructure: preserveRelativeStructure,
        includeSubdirectories: includeSubdirectories,
        dryRun: dryRun,
        ignoreHiddenFiles: ignoreHiddenFiles,
        collisionPolicy: collisionPolicy,
        profile: profile
    )
}
