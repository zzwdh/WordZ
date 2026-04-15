import Foundation

package final class UpdateDownloadBridge: NSObject, URLSessionDownloadDelegate, NativeUpdateDownloading, @unchecked Sendable {
    private let destinationURL: URL
    private let onProgress: @MainActor (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var hasFinished = false

    package init(destinationURL: URL, onProgress: @escaping @MainActor (Double) -> Void) {
        self.destinationURL = destinationURL
        self.onProgress = onProgress
    }

    package func run(downloadURL: URL, configuration: URLSessionConfiguration) async throws -> URL {
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: downloadURL).resume()
        }
    }

    package func download(
        from remoteURL: URL,
        to destinationURL: URL,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> URL {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 600
        let bridge = UpdateDownloadBridge(destinationURL: destinationURL, onProgress: onProgress)
        return try await bridge.run(downloadURL: remoteURL, configuration: configuration)
    }

    package func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.onProgress(progress)
        }
    }

    package func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard !hasFinished else { return }
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            hasFinished = true
            let messagePrefix = "更新下载失败（HTTP \(httpResponse.statusCode)）。"
            let responseBody = (try? String(contentsOf: location, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let description = responseBody.flatMap { body in
                body.isEmpty ? nil : "\(messagePrefix) \(body)"
            } ?? messagePrefix
            continuation?.resume(throwing: NSError(
                domain: "WordZMac.GitHubReleaseUpdateService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: description]
            ))
            continuation = nil
            return
        }
        hasFinished = true
        do {
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            continuation?.resume(returning: destinationURL)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    package func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !hasFinished, let error else { return }
        hasFinished = true
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
