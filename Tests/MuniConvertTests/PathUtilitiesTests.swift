import Foundation
import Testing
@testable import MuniConvertCore

struct PathUtilitiesTests {
    @Test
    func temporaryAndHiddenDetection() {
        #expect(PathUtilities.isTemporaryOrHiddenFile(named: "~$Budget.xls", ignoreHiddenFiles: true))
        #expect(PathUtilities.isTemporaryOrHiddenFile(named: ".DS_Store", ignoreHiddenFiles: true))
        #expect(PathUtilities.isTemporaryOrHiddenFile(named: ".hidden.doc", ignoreHiddenFiles: true))

        #expect(!PathUtilities.isTemporaryOrHiddenFile(named: ".hidden.doc", ignoreHiddenFiles: false))
        #expect(!PathUtilities.isTemporaryOrHiddenFile(named: "rapport.doc", ignoreHiddenFiles: true))
    }

    @Test
    func resolveTargetWithoutCollisionInSourceFolder() throws {
        let temp = try TempDirectory()
        let sourceFile = try temp.createFile("Rapport.doc")
        let options = makeOptions(source: temp.url)

        let resolution = try PathUtilities.resolveTargetURL(for: sourceFile, options: options)

        #expect(!resolution.skippedBecauseExists)
        #expect(resolution.targetURL?.lastPathComponent == "Rapport.pdf")
    }

    @Test
    func resolveTargetSkipExistingPolicy() throws {
        let temp = try TempDirectory()
        let sourceFile = try temp.createFile("Rapport.doc")
        _ = try temp.createFile("Rapport.pdf", contents: "existing")

        let options = makeOptions(source: temp.url, collisionPolicy: CollisionPolicy.skipExisting)

        let resolution = try PathUtilities.resolveTargetURL(for: sourceFile, options: options)

        #expect(resolution.skippedBecauseExists)
        #expect(resolution.targetURL == nil)
    }

    @Test
    func resolveTargetOverwritePolicy() throws {
        let temp = try TempDirectory()
        let sourceFile = try temp.createFile("Rapport.doc")
        _ = try temp.createFile("Rapport.pdf", contents: "existing")

        let options = makeOptions(source: temp.url, collisionPolicy: CollisionPolicy.overwrite)

        let resolution = try PathUtilities.resolveTargetURL(for: sourceFile, options: options)

        #expect(!resolution.skippedBecauseExists)
        #expect(resolution.targetURL?.lastPathComponent == "Rapport.pdf")
    }

    @Test
    func resolveTargetRenamePolicy() throws {
        let temp = try TempDirectory()
        let sourceFile = try temp.createFile("Rapport.doc")
        _ = try temp.createFile("Rapport.pdf", contents: "existing")
        _ = try temp.createFile("Rapport (1).pdf", contents: "existing")

        let options = makeOptions(source: temp.url, collisionPolicy: CollisionPolicy.renameWithSuffix)

        let resolution = try PathUtilities.resolveTargetURL(for: sourceFile, options: options)

        #expect(!resolution.skippedBecauseExists)
        #expect(resolution.targetURL?.lastPathComponent == "Rapport (2).pdf")
    }

    @Test
    func preserveRelativeStructureForSeparateOutput() throws {
        let temp = try TempDirectory()
        let sourceRoot = try temp.createDirectory("Source")
        let outputRoot = try temp.createDirectory("Sortie")
        let sourceFile = sourceRoot
            .appendingPathComponent("Niveau1", isDirectory: true)
            .appendingPathComponent("Niveau2", isDirectory: true)
            .appendingPathComponent("Fichier.doc")

        try FileManager.default.createDirectory(
            at: sourceFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "data".data(using: .utf8)?.write(to: sourceFile)

        let options = makeOptions(
            source: sourceRoot,
            output: outputRoot,
            useSeparateOutputFolder: true,
            preserveRelativeStructure: true
        )

        let resolution = try PathUtilities.resolveTargetURL(for: sourceFile, options: options)

        let targetURL = try #require(resolution.targetURL)
        #expect(targetURL.path == outputRoot
            .appendingPathComponent("Niveau1/Niveau2/Fichier.pdf").path)
    }
}
