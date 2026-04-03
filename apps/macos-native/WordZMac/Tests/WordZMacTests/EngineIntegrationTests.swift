import XCTest
@testable import WordZMac

final class EngineIntegrationTests: XCTestCase {
    @MainActor
    func testNativeWorkspaceRepositoryBootstrapsAgainstNativeUserDataDirectory() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = URL(fileURLWithPath: "/Users/zouyuxuan/corpus-lite/.wordz-native-user-data-test", isDirectory: true)

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
}
