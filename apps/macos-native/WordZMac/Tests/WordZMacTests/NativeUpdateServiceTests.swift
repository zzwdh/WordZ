import XCTest
@testable import WordZWorkspaceCore

import WordZHost
final class NativeUpdateServiceTests: XCTestCase {
    override func tearDown() {
        MockUpdateURLProtocol.handler = nil
        ControlledAPIURLProtocol.onStartLoading = nil
        ControlledAPIURLProtocol.onStopLoading = nil
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

    func testGitHubReleasePayloadParserPrefersDmgInstallerOverPkgAndZip() {
        let result = GitHubReleasePayloadParser.parse([
            "tag_name": "v1.3.9",
            "name": "WordZ 1.3.9",
            "assets": [
                [
                    "name": "WordZ-1.3.9-mac-arm64.zip",
                    "browser_download_url": "https://example.com/WordZ-1.3.9.zip"
                ],
                [
                    "name": "WordZ-1.3.9-mac-arm64.pkg",
                    "browser_download_url": "https://example.com/WordZ-1.3.9.pkg"
                ],
                [
                    "name": "WordZ-1.3.9-mac-arm64.dmg",
                    "browser_download_url": "https://example.com/WordZ-1.3.9.dmg"
                ]
            ]
        ], currentVersion: "1.3.8")

        XCTAssertEqual(result.asset?.name, "WordZ-1.3.9-mac-arm64.dmg")
    }

    func testGitHubReleasePayloadParserAcceptsPkgInstallerWhenNoDmgExists() {
        let result = GitHubReleasePayloadParser.parse([
            "tag_name": "v1.3.9",
            "name": "WordZ 1.3.9",
            "assets": [
                [
                    "name": "WordZ-1.3.9-mac-arm64.pkg",
                    "browser_download_url": "https://example.com/WordZ-1.3.9.pkg"
                ]
            ]
        ], currentVersion: "1.3.8")

        XCTAssertEqual(result.asset?.name, "WordZ-1.3.9-mac-arm64.pkg")
    }

    @MainActor
    func testCheckForUpdatesUsesUnifiedAPIHeaders() async throws {
        MockUpdateURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "WordZMac Update Checker")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("""
            {
              "tag_name": "v1.4.0",
              "name": "WordZ 1.4.0",
              "html_url": "https://github.com/zzwdh/WordZ/releases/tag/v1.4.0",
              "assets": []
            }
            """.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockUpdateURLProtocol.self]
        let service = GitHubReleaseUpdateService(
            session: URLSession(configuration: configuration),
            latestReleaseURL: URL(string: "https://example.com/releases/latest")!
        )

        let result = try await service.checkForUpdates(currentVersion: "1.3.9")
        XCTAssertTrue(result.updateAvailable)
        XCTAssertEqual(result.latestVersion, "v1.4.0")
    }

    func testNativeAPIClientRetriesRateLimitedRequest() async throws {
        var requestCount = 0
        MockUpdateURLProtocol.handler = { request in
            requestCount += 1
            if requestCount == 1 {
                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: [
                        "Content-Type": "application/json",
                        "Retry-After": "0"
                    ]
                )!
                return (response, Data("{\"message\":\"rate limited\"}".utf8))
            }

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["ETag": "\"release-v1\""]
            )!
            return (response, Data("{\"ok\":true}".utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockUpdateURLProtocol.self]
        let client = NativeAPIClient(
            session: URLSession(configuration: configuration),
            retryPolicy: NativeAPIRetryPolicy(maxRetries: 1, baseDelayNanoseconds: 0),
            maxConcurrentRequests: 1,
            defaultUserAgent: "WordZMac Tests"
        )

        let response = try await client.send(NativeAPIRequest(url: URL(string: "https://example.com/api")!))

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.attemptCount, 2)
        XCTAssertEqual(response.etag, "\"release-v1\"")
    }

    func testNativeAPIClientRedactsSensitiveHeaders() {
        let redacted = NativeAPIClient.redactedHeaders([
            "Authorization": "Bearer abc",
            "X-Api-Key": "secret-key",
            "Content-Type": "application/json"
        ])

        XCTAssertEqual(redacted["Authorization"], "[redacted]")
        XCTAssertEqual(redacted["X-Api-Key"], "[redacted]")
        XCTAssertEqual(redacted["Content-Type"], "application/json")
    }

    func testNativeAPIConnectionTestServiceUsesUnifiedClientAndCredentialHeader() async throws {
        MockUpdateURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/rate_limit")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-abc")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "WordZMac Tests")
            XCTAssertEqual(request.timeoutInterval, 15, accuracy: 0.01)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"ok\":true}".utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockUpdateURLProtocol.self]
        let service = NativeAPIConnectionTestService(
            endpointURL: URL(string: "https://example.com/rate_limit")!,
            session: URLSession(configuration: configuration),
            defaultUserAgent: "WordZMac Tests"
        )

        let result = try await service.testConnection(
            credential: " token-abc ",
            timeoutSeconds: 15,
            maxConcurrentRequests: 2
        )

        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.attemptCount, 1)
        XCTAssertEqual(result.endpointHost, "example.com")
    }

    func testNativeAPIClientCancelsInFlightRequestWithoutWrappingAsTransportError() async throws {
        let started = expectation(description: "request started")
        let lock = NSLock()
        var startCount = 0
        var runningProtocol: ControlledAPIURLProtocol?

        ControlledAPIURLProtocol.onStartLoading = { _, urlProtocol in
            lock.withLock {
                startCount += 1
                runningProtocol = urlProtocol
            }
            started.fulfill()
        }

        let client = NativeAPIClient(
            session: URLSession(configuration: controlledAPIConfiguration()),
            retryPolicy: .disabled,
            maxConcurrentRequests: 1,
            defaultUserAgent: "WordZMac Tests"
        )

        let task = Task {
            try await client.send(NativeAPIRequest(url: URL(string: "https://example.com/api/cancel")!))
        }

        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        try XCTUnwrap(lock.withLock { runningProtocol }).fail(URLError(.cancelled))

        do {
            _ = try await task.value
            XCTFail("Expected in-flight API request cancellation")
        } catch is CancellationError {
            // Expected cancellation path.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        let observedStartCount = lock.withLock { startCount }
        XCTAssertEqual(observedStartCount, 1)
    }

    func testNativeAPIClientCancelsQueuedRequestAndKeepsLaterRequestsRunning() async throws {
        let firstStarted = expectation(description: "first request started")
        let thirdStarted = expectation(description: "third request started")
        let lock = NSLock()
        var firstProtocol: ControlledAPIURLProtocol?
        var thirdDidStart = false

        ControlledAPIURLProtocol.onStartLoading = { request, urlProtocol in
            switch request.url?.path {
            case "/api/first":
                lock.withLock {
                    firstProtocol = urlProtocol
                }
                firstStarted.fulfill()
            case "/api/third":
                lock.withLock {
                    thirdDidStart = true
                }
                thirdStarted.fulfill()
                urlProtocol.respond(statusCode: 200, data: Data("{\"ok\":true}".utf8))
            default:
                urlProtocol.respond(statusCode: 500, data: Data())
            }
        }

        let client = NativeAPIClient(
            session: URLSession(configuration: controlledAPIConfiguration()),
            retryPolicy: .disabled,
            maxConcurrentRequests: 1,
            defaultUserAgent: "WordZMac Tests"
        )

        let firstTask = Task {
            try await client.send(NativeAPIRequest(url: URL(string: "https://example.com/api/first")!))
        }
        await fulfillment(of: [firstStarted], timeout: 1)

        let queuedTask = Task {
            try await client.send(NativeAPIRequest(url: URL(string: "https://example.com/api/queued")!))
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        queuedTask.cancel()

        do {
            _ = try await queuedTask.value
            XCTFail("Expected queued API request cancellation")
        } catch is CancellationError {
            // Expected cancellation path.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        let firstProtocolSnapshot = lock.withLock { firstProtocol }
        try XCTUnwrap(firstProtocolSnapshot).respond(statusCode: 200, data: Data("{\"ok\":true}".utf8))
        _ = try await firstTask.value

        let thirdTask = Task {
            try await client.send(NativeAPIRequest(url: URL(string: "https://example.com/api/third")!))
        }
        await fulfillment(of: [thirdStarted], timeout: 1)

        let observedThirdDidStart = lock.withLock { thirdDidStart }
        XCTAssertTrue(observedThirdDidStart)
        guard observedThirdDidStart else {
            thirdTask.cancel()
            return
        }

        let response = try await thirdTask.value
        XCTAssertEqual(response.statusCode, 200)
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

private func controlledAPIConfiguration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ControlledAPIURLProtocol.self]
    return configuration
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

private final class ControlledAPIURLProtocol: URLProtocol {
    nonisolated(unsafe) static var onStartLoading: ((URLRequest, ControlledAPIURLProtocol) -> Void)?
    nonisolated(unsafe) static var onStopLoading: ((URLRequest) -> Void)?

    private let lock = NSLock()
    private var completed = false

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.onStartLoading?(request, self)
    }

    override func stopLoading() {
        Self.onStopLoading?(request)
        fail(URLError(.cancelled))
    }

    func respond(statusCode: Int, data: Data, headers: [String: String] = [:]) {
        guard completeIfNeeded() else { return }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    func fail(_ error: Error) {
        guard completeIfNeeded() else { return }
        client?.urlProtocol(self, didFailWithError: error)
    }

    private func completeIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return false }
        completed = true
        return true
    }
}
