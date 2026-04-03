import XCTest
@testable import WordZMac

final class EngineIntegrationTests: XCTestCase {
    @MainActor
    func testNativeWorkspaceRepositoryBootstrapsAgainstNativeUserDataDirectory() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            ".wordz-native-user-data-test",
            isDirectory: true
        )

        try? FileManager.default.removeItem(at: userDataURL)

        do {
            try await repository.start(userDataURL: userDataURL)
            let bootstrap = try await repository.loadBootstrapState()
            XCTAssertEqual(bootstrap.appInfo.name, "WordZ")
            XCTAssertEqual(bootstrap.librarySnapshot.folders.count, 0)
            XCTAssertEqual(bootstrap.librarySnapshot.corpora.count, 0)
            XCTAssertEqual(bootstrap.workspaceSnapshot.currentTab, "stats")
        } catch {
            XCTFail("Native engine bootstrap failed: \(error.localizedDescription)")
        }

        await repository.stop()
    }

    @MainActor
    func testNativeWorkspaceRepositoryLoadsCorpusInfoFromStoredDatabaseMetadata() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            ".wordz-native-user-data-corpus-info-test",
            isDirectory: true
        )
        let importURL = userDataURL.appendingPathComponent("sample.txt")

        try? FileManager.default.removeItem(at: userDataURL)
        try FileManager.default.createDirectory(at: userDataURL, withIntermediateDirectories: true)
        try "Alpha beta gamma.\nAlpha beta.".write(to: importURL, atomically: true, encoding: .utf8)

        do {
            try await repository.start(userDataURL: userDataURL)
            _ = try await repository.importCorpusPaths([importURL.path], folderId: "", preserveHierarchy: false)
            let library = try await repository.listLibrary(folderId: "all")
            guard let corpus = library.corpora.first else {
                XCTFail("Expected imported corpus")
                return
            }

            let info = try await repository.loadCorpusInfo(corpusId: corpus.id)

            XCTAssertEqual(info.title, corpus.name)
            XCTAssertEqual(info.detectedEncoding.uppercased(), "UTF-8")
            XCTAssertGreaterThan(info.tokenCount, 0)
            XCTAssertGreaterThan(info.typeCount, 0)
            XCTAssertGreaterThan(info.ttr, 0)
        } catch {
            XCTFail("Native corpus info failed: \(error.localizedDescription)")
        }

        await repository.stop()
    }
}
