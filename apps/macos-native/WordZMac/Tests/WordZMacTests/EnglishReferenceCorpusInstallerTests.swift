import XCTest
@testable import WordZWorkspaceCore

final class EnglishReferenceCorpusInstallerTests: XCTestCase {
    func testEnglishReferenceCorpusCatalogDescribesSupportedCorpora() {
        XCTAssertEqual(EnglishReferenceCorpusCatalog.all.map(\.kind), [.bnc1994, .oanc])
        XCTAssertEqual(EnglishReferenceCorpusCatalog.descriptor(for: .bnc1994).shortName, "BNC1994")
        XCTAssertEqual(EnglishReferenceCorpusCatalog.descriptor(for: .oanc).shortName, "OANC")
        XCTAssertFalse(EnglishReferenceCorpusCatalog.descriptor(for: .bnc1994).canBundleWithApp)
        XCTAssertFalse(EnglishReferenceCorpusCatalog.descriptor(for: .oanc).canBundleWithApp)
        XCTAssertTrue(EnglishReferenceCorpusCatalog.descriptor(for: .bnc1994).licenceNote.contains("BNC"))
        XCTAssertTrue(EnglishReferenceCorpusCatalog.descriptor(for: .oanc).downloadPageURL.absoluteString.contains("anc.org"))
    }

    func testPrepareExtractedOANCSkipsLicenceFilesAndNormalizesText() throws {
        let rootURL = temporaryDirectory(named: "wordz-oanc-prepare")
        let sourceURL = rootURL.appendingPathComponent("source", isDirectory: true)
        let outputURL = rootURL.appendingPathComponent("prepared", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try "Ignore me".write(
            to: sourceURL.appendingPathComponent("README.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "Alpha\t beta\r\n\n\nGamma".write(
            to: sourceURL.appendingPathComponent("story.text"),
            atomically: true,
            encoding: .utf8
        )

        try EnglishReferenceCorpusDownloadInstaller.prepareExtractedCorpus(
            .oanc,
            from: sourceURL,
            to: outputURL,
            minimumCharacterCount: 1
        )

        let preparedFiles = try FileManager.default.contentsOfDirectory(
            at: outputURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(preparedFiles.map(\.lastPathComponent), ["story.txt"])
        XCTAssertEqual(
            try String(contentsOf: outputURL.appendingPathComponent("story.txt"), encoding: .utf8),
            "Alpha beta Gamma\n"
        )
    }

    func testPrepareExtractedBNCWritesTokenizedText() throws {
        let rootURL = temporaryDirectory(named: "wordz-bnc-prepare")
        let sourceURL = rootURL.appendingPathComponent("source", isDirectory: true)
        let textsURL = sourceURL.appendingPathComponent("Texts", isDirectory: true)
        let outputURL = rootURL.appendingPathComponent("prepared", isDirectory: true)
        try FileManager.default.createDirectory(at: textsURL, withIntermediateDirectories: true)
        try """
        <bncDoc><text><s><w>Hello</w><w>world</w><c>!</c></s></text></bncDoc>
        """.write(
            to: textsURL.appendingPathComponent("sample.xml"),
            atomically: true,
            encoding: .utf8
        )

        try EnglishReferenceCorpusDownloadInstaller.prepareExtractedCorpus(
            .bnc1994,
            from: sourceURL,
            to: outputURL,
            minimumCharacterCount: 1
        )

        XCTAssertEqual(
            try String(contentsOf: outputURL.appendingPathComponent("sample.txt"), encoding: .utf8),
            "Hello world!\n"
        )
    }

    func testPrepareExtractedCorpusFailsWhenNoImportableTextExists() throws {
        let rootURL = temporaryDirectory(named: "wordz-reference-empty")
        let sourceURL = rootURL.appendingPathComponent("source", isDirectory: true)
        let outputURL = rootURL.appendingPathComponent("prepared", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(
            try EnglishReferenceCorpusDownloadInstaller.prepareExtractedCorpus(
                .oanc,
                from: sourceURL,
                to: outputURL,
                minimumCharacterCount: 1
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("没有找到可导入的正文文件"))
        }
    }

    @MainActor
    func testInstallPreparedTextDirectorySavesMergedCorpusSetSummary() async throws {
        let rootURL = temporaryDirectory(named: "wordz-reference-install")
        let sourceURL = rootURL.appendingPathComponent("prepared", isDirectory: true)
        let userDataURL = rootURL.appendingPathComponent("user-data", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try "Alpha beta gamma.".write(to: sourceURL.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "Delta epsilon.".write(to: sourceURL.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        let summary = try await ReferenceCorpusInstaller.installPreparedTextDirectory(
            sourceDirectory: sourceURL,
            corpusSetName: "Test English Reference",
            userDataURL: userDataURL,
            mergeIntoSingleCorpus: true,
            seedBundledDefaultReferenceCorpora: false
        )

        XCTAssertEqual(summary.corpusSetName, "Test English Reference")
        XCTAssertEqual(summary.sourceFileCount, 2)
        XCTAssertEqual(summary.importedCount, 1)
        XCTAssertEqual(summary.skippedCount, 0)
        XCTAssertEqual(summary.corpusIDs.count, 1)
        XCTAssertTrue(summary.failureMessages.isEmpty)

        let repository = NativeWorkspaceRepository(
            rootURL: userDataURL,
            seedBundledDefaultReferenceCorpora: false
        )
        try await repository.start(userDataURL: userDataURL)
        let openedSet = try await repository.openSavedCorpusSet(corpusSetID: summary.corpusSetID)
        XCTAssertEqual(openedSet.mode, "corpus-set")
        XCTAssertTrue(openedSet.content.contains("Alpha beta gamma."))
        XCTAssertTrue(openedSet.content.contains("Delta epsilon."))
        await repository.stop()
    }

    private func temporaryDirectory(named prefix: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
