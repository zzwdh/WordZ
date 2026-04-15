import XCTest
@testable import WordZWorkspaceCore

private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func isSet() -> Bool {
        lock.lock()
        let snapshot = value
        lock.unlock()
        return snapshot
    }
}

final class NativeCorpusStoreMaintenanceTests: XCTestCase {
    func testBackupLibraryRejectsDestinationInsideRoot() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-backup")
        let destinationURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        XCTAssertThrowsError(try store.backupLibrary(destinationPath: destinationURL.path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("备份目录不能位于当前语料库目录内部"))
        }
        let createdBackupDirectories = (try? fileManager.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil)) ?? []
        XCTAssertTrue(createdBackupDirectories.isEmpty)
    }

    func testRepairLibraryMovesUnreadableStorageIntoQuarantineDirectory() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-repair")
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)
        let record = try XCTUnwrap(store.loadCorpora().first(where: { $0.id == corpus.id }))
        let storageURL = store.corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        try fileManager.setAttributes([.posixPermissions: 0], ofItemAtPath: storageURL.path)

        let summary = try store.repairLibrary()

        XCTAssertEqual(summary.checkedCorpora, 1)
        XCTAssertEqual(summary.repairedCorpora, 1)
        XCTAssertEqual(summary.quarantinedCorpora, 1)
        XCTAssertTrue(summary.repairedManifest)
        XCTAssertTrue(try store.loadCorpora().isEmpty)
        XCTAssertFalse(fileManager.fileExists(atPath: storageURL.path))

        let quarantineURL = URL(fileURLWithPath: summary.quarantineDir, isDirectory: true)
        let quarantinedFileURL = quarantineURL.appendingPathComponent(record.storageFileName)
        XCTAssertTrue(fileManager.fileExists(atPath: quarantinedFileURL.path))
        XCTAssertTrue(quarantineURL.lastPathComponent.hasPrefix("repair-quarantine-"))
    }

    func testRestoreLibraryRejectsSourceInsideCurrentRootAndPreservesLibraryState() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-restore")
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)
        let nestedBackupURL = rootURL.appendingPathComponent("nested-backup", isDirectory: true)
        try fileManager.createDirectory(at: nestedBackupURL, withIntermediateDirectories: true)

        let beforeSnapshot = try store.listLibrary(folderId: "all")
        XCTAssertThrowsError(try store.restoreLibrary(sourcePath: nestedBackupURL.path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("恢复源目录不能位于当前语料库目录内部"))
        }

        let afterSnapshot = try store.listLibrary(folderId: "all")
        XCTAssertEqual(afterSnapshot.corpora.count, beforeSnapshot.corpora.count)
        XCTAssertEqual(afterSnapshot.corpora.first?.id, corpus.id)
        XCTAssertEqual(afterSnapshot.corpora.first?.name, corpus.name)
    }

    func testProgressImportCancellationRollsBackManifestAndStagingFiles() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-import-cancel")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let firstURL = rootURL.appendingPathComponent("first.txt")
        let secondURL = rootURL.appendingPathComponent("second.txt")
        try "alpha beta gamma".write(to: firstURL, atomically: true, encoding: .utf8)
        try "delta epsilon zeta".write(to: secondURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        let shouldCancel = CancellationFlag()
        XCTAssertThrowsError(
            try store.importCorpusPaths(
                [firstURL.path, secondURL.path],
                folderId: "",
                preserveHierarchy: false,
                progress: { snapshot in
                    if snapshot.phase == .importing, snapshot.completedCount >= 1 {
                        shouldCancel.set()
                    }
                },
                isCancelled: { shouldCancel.isSet() }
            )
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }

        XCTAssertTrue(try store.listLibrary(folderId: "all").corpora.isEmpty)
        let remainingRootEntries = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
        XCTAssertFalse(remainingRootEntries.contains(where: { $0.lastPathComponent.hasPrefix("import-staging-") }))
    }

    func testProgressImportCollectsFailureItemsForSkippedFiles() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-import-failures")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let textURL = rootURL.appendingPathComponent("sample.txt")
        let imageURL = rootURL.appendingPathComponent("sample.png")
        try "alpha beta gamma".write(to: textURL, atomically: true, encoding: .utf8)
        try Data([0x89, 0x50, 0x4E, 0x47, 0x00]).write(to: imageURL, options: .atomic)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let result = try store.importCorpusPaths(
            [textURL.path, imageURL.path],
            folderId: "",
            preserveHierarchy: false,
            progress: nil,
            isCancelled: nil
        )

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(result.failureItems.count, 1)
        XCTAssertEqual(result.failureItems.first?.fileName, "sample.png")
        XCTAssertTrue(result.failureItems.first?.reason.contains("暂不支持") == true)
    }

    func testImportCorpusPathsStoresRawTextAndCleanedContent() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-auto-cleaning-import")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        let rawText = "\u{FEFF}\nAlpha\u{00A0}Beta\t\u{200B}\r\nLine\u{0000} two  \n\n"
        try rawText.write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let result = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)

        let corpus = try XCTUnwrap(result.importedItems.first)
        XCTAssertEqual(result.cleaningSummary.cleanedCount, 1)
        XCTAssertEqual(result.cleaningSummary.changedCount, 1)
        XCTAssertEqual(corpus.cleaningStatus, .cleanedWithChanges)

        let opened = try store.openSavedCorpus(corpusId: corpus.id)
        XCTAssertEqual(opened.content, "Alpha Beta\nLine two")

        let record = try XCTUnwrap(store.loadCorpora().first(where: { $0.id == corpus.id }))
        let storageURL = store.corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        let storedDocument = try XCTUnwrap(NativeCorpusDatabaseSupport.readDocument(at: storageURL))
        XCTAssertEqual(storedDocument.rawText, rawText)
        XCTAssertEqual(storedDocument.text, "Alpha Beta\nLine two")
    }

    func testCleanCorporaReusesStoredRawTextAndReportsChanges() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-auto-cleaning-rerun")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try "\u{FEFF}\nAlpha\u{00A0}Beta\t\u{200B}\r\nLine\u{0000} two  \n\n".write(
            to: sourceURL,
            atomically: true,
            encoding: .utf8
        )

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)

        let result = try store.cleanCorpora(corpusIds: [corpus.id])

        XCTAssertEqual(result.requestedCount, 1)
        XCTAssertEqual(result.cleanedCount, 1)
        XCTAssertEqual(result.changedCount, 1)
        XCTAssertEqual(result.cleanedItems.first?.id, corpus.id)
        XCTAssertEqual(result.cleanedItems.first?.cleaningStatus, .cleanedWithChanges)
        XCTAssertEqual(try store.openSavedCorpus(corpusId: corpus.id).content, "Alpha Beta\nLine two")
    }

    private func temporaryDirectory(named prefix: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    }
}
