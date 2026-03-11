import Testing
@testable import MuniConvert

struct FileScannerTests {
    @Test
    func scannerFiltersStrictlyAndIgnoresTemporaryFiles() throws {
        let temp = try TempDirectory()
        _ = try temp.createFile("A.doc")
        _ = try temp.createFile("B.DOC")
        _ = try temp.createFile("C.docx")
        _ = try temp.createFile("~$Temp.doc")
        _ = try temp.createFile(".DS_Store")
        _ = try temp.createFile(".cache.doc")

        let options = makeOptions(
            source: temp.url,
            includeSubdirectories: false,
            ignoreHiddenFiles: true,
            profileID: "doc_to_pdf"
        )

        let scanner = FileScanner()
        let result = try scanner.scan(options: options)

        #expect(result.totalScanned == 6)
        #expect(result.totalIgnored == 4)

        let matchedNames = Set(result.matchedFiles.map { $0.lastPathComponent })
        #expect(matchedNames == Set(["A.doc", "B.DOC"]))

        let matchedLogs = result.logs.filter { $0.status == LogStatus.matched }
        #expect(matchedLogs.count == 2)
    }

    @Test
    func scannerRespectsRecursiveOption() throws {
        let temp = try TempDirectory()
        _ = try temp.createFile("Racine.doc")
        _ = try temp.createFile("Sous/Niveau/Fichier.doc")

        let scanner = FileScanner()

        let nonRecursive = try scanner.scan(options: makeOptions(
            source: temp.url,
            includeSubdirectories: false,
            profileID: "doc_to_pdf"
        ))
        #expect(nonRecursive.matchedFiles.count == 1)

        let recursive = try scanner.scan(options: makeOptions(
            source: temp.url,
            includeSubdirectories: true,
            profileID: "doc_to_pdf"
        ))
        #expect(recursive.matchedFiles.count == 2)
    }

    @Test
    func scannerRespectsSelectedProfileOnly() throws {
        let temp = try TempDirectory()
        _ = try temp.createFile("Tableau.xls")
        _ = try temp.createFile("Document.doc")

        let scanner = FileScanner()
        let options = makeOptions(
            source: temp.url,
            includeSubdirectories: false,
            profileID: "xls_to_pdf"
        )

        let result = try scanner.scan(options: options)

        #expect(result.matchedFiles.count == 1)
        #expect(result.matchedFiles.first?.lastPathComponent == "Tableau.xls")
    }
}
