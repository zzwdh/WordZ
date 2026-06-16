import Foundation

package struct NativeAPIConnectionTestResult: Equatable, Sendable {
    package let statusCode: Int
    package let durationMilliseconds: Int
    package let attemptCount: Int
    package let endpointHost: String

    package init(
        statusCode: Int,
        durationMilliseconds: Int,
        attemptCount: Int,
        endpointHost: String
    ) {
        self.statusCode = statusCode
        self.durationMilliseconds = durationMilliseconds
        self.attemptCount = attemptCount
        self.endpointHost = endpointHost
    }
}

package protocol NativeAPIConnectionTesting: AnyObject, Sendable {
    func testConnection(
        credential: String?,
        timeoutSeconds: Int,
        maxConcurrentRequests: Int
    ) async throws -> NativeAPIConnectionTestResult
}

package final class NativeAPIConnectionTestService: NativeAPIConnectionTesting, @unchecked Sendable {
    private let endpointURL: URL
    private let session: URLSession?
    private let retryPolicy: NativeAPIRetryPolicy
    private let defaultUserAgent: String

    package init(
        endpointURL: URL = URL(string: "https://api.github.com/rate_limit")!,
        session: URLSession? = nil,
        retryPolicy: NativeAPIRetryPolicy = .disabled,
        defaultUserAgent: String = "WordZMac API Connection Check"
    ) {
        self.endpointURL = endpointURL
        self.session = session
        self.retryPolicy = retryPolicy
        self.defaultUserAgent = defaultUserAgent
    }

    package func testConnection(
        credential: String?,
        timeoutSeconds: Int,
        maxConcurrentRequests: Int
    ) async throws -> NativeAPIConnectionTestResult {
        let resolvedCredential = credential?.trimmingCharacters(in: .whitespacesAndNewlines)
        var headers = [
            "Accept": "application/vnd.github+json"
        ]
        if let resolvedCredential, !resolvedCredential.isEmpty {
            headers["Authorization"] = "Bearer \(resolvedCredential)"
        }

        let client = NativeAPIClient(
            session: session,
            retryPolicy: retryPolicy,
            maxConcurrentRequests: Self.clampedMaxConcurrentRequests(maxConcurrentRequests),
            defaultUserAgent: defaultUserAgent
        )
        let response = try await client.send(NativeAPIRequest(
            url: endpointURL,
            headers: headers,
            timeoutInterval: TimeInterval(Self.clampedTimeoutSeconds(timeoutSeconds)),
            allowsRetries: false
        ))
        return NativeAPIConnectionTestResult(
            statusCode: response.statusCode,
            durationMilliseconds: response.durationMilliseconds,
            attemptCount: response.attemptCount,
            endpointHost: endpointURL.host ?? endpointURL.absoluteString
        )
    }

    private static func clampedTimeoutSeconds(_ timeoutSeconds: Int) -> Int {
        min(max(timeoutSeconds, 5), 60)
    }

    private static func clampedMaxConcurrentRequests(_ maxConcurrentRequests: Int) -> Int {
        min(max(maxConcurrentRequests, 1), 4)
    }
}
