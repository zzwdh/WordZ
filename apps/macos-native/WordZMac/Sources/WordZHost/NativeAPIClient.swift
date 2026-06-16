import Foundation

package enum NativeAPIHTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

package struct NativeAPIRequest: Sendable {
    package let id: UUID
    package let url: URL
    package let method: NativeAPIHTTPMethod
    package let headers: [String: String]
    package let body: Data?
    package let timeoutInterval: TimeInterval
    package let allowsRetries: Bool

    package init(
        id: UUID = UUID(),
        url: URL,
        method: NativeAPIHTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval = 10,
        allowsRetries: Bool = true
    ) {
        self.id = id
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.allowsRetries = allowsRetries
    }

    package func urlRequest(defaultUserAgent: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.timeoutInterval = timeoutInterval
        request.setValue(defaultUserAgent, forHTTPHeaderField: "User-Agent")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

package struct NativeAPIResponse: Sendable {
    package let requestID: UUID
    package let data: Data
    package let statusCode: Int
    package let headers: [String: String]
    package let durationMilliseconds: Int
    package let attemptCount: Int

    package var etag: String? {
        header(named: "ETag")
    }

    package func header(named name: String) -> String? {
        let lowercased = name.lowercased()
        return headers.first(where: { $0.key.lowercased() == lowercased })?.value
    }
}

package struct NativeAPIRetryPolicy: Sendable {
    package let maxRetries: Int
    package let baseDelayNanoseconds: UInt64
    package let retryableStatusCodes: Set<Int>

    package init(
        maxRetries: Int = 1,
        baseDelayNanoseconds: UInt64 = 150_000_000,
        retryableStatusCodes: Set<Int> = Set([408, 425, 429] + Array(500...599))
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelayNanoseconds = baseDelayNanoseconds
        self.retryableStatusCodes = retryableStatusCodes
    }

    package static let disabled = NativeAPIRetryPolicy(maxRetries: 0, baseDelayNanoseconds: 0)

    package func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        attempt <= maxRetries && retryableStatusCodes.contains(statusCode)
    }

    package func retryDelayNanoseconds(for attempt: Int, retryAfterSeconds: TimeInterval?) -> UInt64 {
        if let retryAfterSeconds, retryAfterSeconds > 0 {
            return UInt64(retryAfterSeconds * 1_000_000_000)
        }
        guard baseDelayNanoseconds > 0 else { return 0 }
        let multiplier = UInt64(max(1, attempt))
        return baseDelayNanoseconds * multiplier
    }
}

package enum NativeAPIClientError: Error, LocalizedError {
    case invalidResponse(requestID: UUID)
    case httpStatus(code: Int, data: Data, requestID: UUID, retryAfterSeconds: TimeInterval?)
    case transport(underlying: Error, requestID: UUID)

    package var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "API 响应格式无效。"
        case .httpStatus(let code, _, _, let retryAfterSeconds):
            if let retryAfterSeconds, retryAfterSeconds > 0 {
                "API 请求失败（HTTP \(code)）。请稍后约 \(Int(retryAfterSeconds)) 秒再试。"
            } else {
                "API 请求失败（HTTP \(code)）。"
            }
        case .transport(let underlying, _):
            "API 请求失败：\(underlying.localizedDescription)"
        }
    }

    package var statusCode: Int? {
        guard case .httpStatus(let code, _, _, _) = self else { return nil }
        return code
    }
}

package final class NativeAPIClient: @unchecked Sendable {
    private let session: URLSession
    private let retryPolicy: NativeAPIRetryPolicy
    private let defaultUserAgent: String
    private let concurrencyLimiter: NativeAPIConcurrencyLimiter

    package init(
        session: URLSession? = nil,
        retryPolicy: NativeAPIRetryPolicy = NativeAPIRetryPolicy(),
        maxConcurrentRequests: Int = 4,
        defaultUserAgent: String = "WordZMac"
    ) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 20
            self.session = URLSession(configuration: configuration)
        }
        self.retryPolicy = retryPolicy
        self.defaultUserAgent = defaultUserAgent
        self.concurrencyLimiter = NativeAPIConcurrencyLimiter(limit: maxConcurrentRequests)
    }

    package func send(_ request: NativeAPIRequest) async throws -> NativeAPIResponse {
        let permitID = UUID()
        try await concurrencyLimiter.acquire(id: permitID)
        defer {
            Task {
                await concurrencyLimiter.release()
            }
        }

        var attempt = 1
        while true {
            try Task.checkCancellation()
            do {
                let urlRequest = request.urlRequest(defaultUserAgent: defaultUserAgent)
                let startedAt = Date()
                let (data, response) = try await session.data(for: urlRequest)
                let durationMilliseconds = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NativeAPIClientError.invalidResponse(requestID: request.id)
                }

                let apiResponse = NativeAPIResponse(
                    requestID: request.id,
                    data: data,
                    statusCode: httpResponse.statusCode,
                    headers: Self.stringHeaders(from: httpResponse),
                    durationMilliseconds: durationMilliseconds,
                    attemptCount: attempt
                )
                if (200..<300).contains(apiResponse.statusCode) {
                    return apiResponse
                }

                let retryAfterSeconds = Self.retryAfterSeconds(from: apiResponse)
                if request.allowsRetries,
                   retryPolicy.shouldRetry(statusCode: apiResponse.statusCode, attempt: attempt) {
                    try await sleepBeforeRetry(attempt: attempt, retryAfterSeconds: retryAfterSeconds)
                    attempt += 1
                    continue
                }

                throw NativeAPIClientError.httpStatus(
                    code: apiResponse.statusCode,
                    data: data,
                    requestID: request.id,
                    retryAfterSeconds: retryAfterSeconds
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as NativeAPIClientError {
                throw error
            } catch {
                if Self.isCancellation(error) || Task.isCancelled {
                    throw CancellationError()
                }
                if request.allowsRetries,
                   retryPolicy.shouldRetry(statusCode: 500, attempt: attempt) {
                    try await sleepBeforeRetry(attempt: attempt, retryAfterSeconds: nil)
                    attempt += 1
                    continue
                }
                throw NativeAPIClientError.transport(underlying: error, requestID: request.id)
            }
        }
    }

    package static func redactedHeaders(_ headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { result, pair in
            result[pair.key] = isSensitiveHeader(pair.key) ? "[redacted]" : pair.value
        }
    }

    private func sleepBeforeRetry(attempt: Int, retryAfterSeconds: TimeInterval?) async throws {
        let delay = retryPolicy.retryDelayNanoseconds(for: attempt, retryAfterSeconds: retryAfterSeconds)
        guard delay > 0 else { return }
        try await Task.sleep(nanoseconds: delay)
    }

    private static func stringHeaders(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [:]) { result, pair in
            guard let key = pair.key as? String else { return }
            result[key] = String(describing: pair.value)
        }
    }

    private static func retryAfterSeconds(from response: NativeAPIResponse) -> TimeInterval? {
        guard let value = response.header(named: "Retry-After") else { return nil }
        return TimeInterval(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func isSensitiveHeader(_ header: String) -> Bool {
        let normalized = header.lowercased()
        return normalized == "authorization"
            || normalized == "proxy-authorization"
            || normalized == "x-api-key"
            || normalized == "api-key"
            || normalized.contains("token")
            || normalized.contains("secret")
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
            && nsError.code == NSURLErrorCancelled
    }
}

private actor NativeAPIConcurrencyLimiter {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private let limit: Int
    private var activeCount = 0
    private var waiters: [Waiter] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func acquire(id: UUID) async throws {
        try Task.checkCancellation()
        if activeCount < limit {
            activeCount += 1
            if Task.isCancelled {
                release()
                throw CancellationError()
            }
            return
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: id)
            }
        }
        if Task.isCancelled {
            release()
            throw CancellationError()
        }
    }

    func release() {
        if waiters.isEmpty {
            activeCount = max(0, activeCount - 1)
            return
        }
        let waiter = waiters.removeFirst()
        waiter.continuation.resume()
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
