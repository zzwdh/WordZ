import XCTest
@testable import WordZMac

final class NativeUpdateServiceTests: XCTestCase {
    override func tearDown() {
        MockUpdateURLProtocol.handler = nil
        super.tearDown()
    }

    func testReleaseVersionComparatorDetectsNewerVersion() {
        XCTAssertTrue(ReleaseVersionComparator.isNewer("1.1.1", than: "1.1.0"))
        XCTAssertTrue(ReleaseVersionComparator.isNewer("v1.1.0", than: "1.0.9"))
        XCTAssertFalse(ReleaseVersionComparator.isNewer("1.1.0", than: "1.1.0"))
        XCTAssertFalse(ReleaseVersionComparator.isNewer("1.0.2", than: "1.0.10"))
    }

    func testGitHubReleasePayloadParserExtractsReleaseMetadata() {
        let result = GitHubReleasePayloadParser.parse([
            "tag_name": "v1.1.1",
            "name": "WordZ 1.1.1",
            "html_url": "https://github.com/zzwdh/WordZ/releases/tag/v1.1.1",
            "published_at": "2026-03-26T00:00:00Z",
            "body": """
            # Highlights
            - Native table layout persistence
            - Better update downloads
            """,
            "assets": [
                [
                    "name": "WordZ-1.1.1-mac-arm64.dmg",
                    "browser_download_url": "https://example.com/WordZ-1.1.1.dmg"
                ]
            ]
        ], currentVersion: "1.1.0")

        XCTAssertTrue(result.updateAvailable)
        XCTAssertEqual(result.latestVersion, "v1.1.1")
        XCTAssertEqual(result.releaseTitle, "WordZ 1.1.1")
        XCTAssertEqual(result.publishedAt, "2026-03-26T00:00:00Z")
        XCTAssertEqual(result.releaseNotes, ["Highlights", "Native table layout persistence", "Better update downloads"])
        XCTAssertEqual(result.asset?.name, "WordZ-1.1.1-mac-arm64.dmg")
    }

    @MainActor
    func testCheckForUpdatesThrowsForNonSuccessfulHTTPStatus() async throws {
        MockUpdateURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 403,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"message\":\"API rate limit exceeded\"}".utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockUpdateURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = GitHubReleaseUpdateService(
            session: session,
            latestReleaseURL: URL(string: "https://example.com/releases/latest")!
        )

        do {
            _ = try await service.checkForUpdates(currentVersion: "1.1.0")
            XCTFail("Expected update check failure")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 403)
            XCTAssertTrue(nsError.localizedDescription.contains("API rate limit exceeded"))
        }
    }

    func testDownloadBridgeRejectsNonSuccessfulHTTPStatus() async throws {
        MockUpdateURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 404,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            return (response, Data("asset not found".utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockUpdateURLProtocol.self]
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-update-\(UUID().uuidString).dmg")
        let bridge = UpdateDownloadBridge(destinationURL: destinationURL, onProgress: { _ in })

        do {
            _ = try await bridge.run(
                downloadURL: URL(string: "https://example.com/WordZ-1.1.1.dmg")!,
                configuration: configuration
            )
            XCTFail("Expected download failure")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 404)
            XCTAssertTrue(nsError.localizedDescription.contains("更新下载失败"))
            XCTAssertTrue(nsError.localizedDescription.contains("asset not found"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
        }
    }
}

private final class MockUpdateURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: "WordZMacTests.MockUpdateURLProtocol",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No mock handler installed."]
            ))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
