import Foundation

@MainActor
package final class GitHubReleaseUpdateService: NativeUpdateServicing {
    private let apiClient: NativeAPIClient
    private let latestReleaseURL: URL
    private let downloadsDirectoryProvider: @Sendable () -> URL
    private let downloaderFactory: @Sendable (_ destinationURL: URL, _ onProgress: @escaping @MainActor (Double) -> Void) -> NativeUpdateDownloading

    package init(
        apiClient: NativeAPIClient? = nil,
        session: URLSession? = nil,
        latestReleaseURL: URL = URL(string: "https://api.github.com/repos/zzwdh/WordZ/releases/latest")!,
        downloadsDirectoryProvider: @escaping @Sendable () -> URL = {
            let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            return baseURL
                .appendingPathComponent("WordZMacNative", isDirectory: true)
                .appendingPathComponent("downloads", isDirectory: true)
                .appendingPathComponent("updates", isDirectory: true)
        },
        downloaderFactory: @escaping @Sendable (_ destinationURL: URL, _ onProgress: @escaping @MainActor (Double) -> Void) -> NativeUpdateDownloading = {
            destinationURL, onProgress in
            UpdateDownloadBridge(destinationURL: destinationURL, onProgress: onProgress)
        }
    ) {
        self.apiClient = apiClient ?? Self.makeDefaultAPIClient(session: session)
        self.latestReleaseURL = latestReleaseURL
        self.downloadsDirectoryProvider = downloadsDirectoryProvider
        self.downloaderFactory = downloaderFactory
    }

    package func checkForUpdates(currentVersion: String) async throws -> NativeUpdateCheckResult {
        let response: NativeAPIResponse
        do {
            response = try await apiClient.send(NativeAPIRequest(
                url: latestReleaseURL,
                headers: [
                    "Accept": "application/vnd.github+json"
                ],
                timeoutInterval: 5
            ))
        } catch let error as NativeAPIClientError {
            throw Self.updateCheckError(from: error)
        }

        guard
            let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        else {
            throw NSError(domain: "WordZMac.GitHubReleaseUpdateService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法解析更新响应。"
            ])
        }

        return GitHubReleasePayloadParser.parse(object, currentVersion: currentVersion)
    }

    package func downloadUpdate(
        _ update: NativeUpdateCheckResult,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> NativeDownloadedUpdate {
        guard update.updateAvailable else {
            throw NSError(domain: "WordZMac.GitHubReleaseUpdateService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "当前没有可下载的更新。"
            ])
        }
        guard let asset = update.asset, let remoteURL = URL(string: asset.downloadURL) else {
            throw NSError(domain: "WordZMac.GitHubReleaseUpdateService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "当前版本缺少可下载的 mac 安装包。"
            ])
        }

        let updatesDirectory = downloadsDirectoryProvider()
        let destinationURL = updatesDirectory.appendingPathComponent(asset.name)
        let downloader = downloaderFactory(destinationURL, onProgress)
        let localURL = try await downloader.download(from: remoteURL, to: destinationURL, onProgress: onProgress)
        return NativeDownloadedUpdate(
            version: update.latestVersion,
            assetName: asset.name,
            localPath: localURL.path,
            releaseURL: update.releaseURL
        )
    }
}

private extension GitHubReleaseUpdateService {
    static func makeDefaultAPIClient(session: URLSession?) -> NativeAPIClient {
        if let session {
            return NativeAPIClient(
                session: session,
                retryPolicy: NativeAPIRetryPolicy(maxRetries: 1, baseDelayNanoseconds: 150_000_000),
                maxConcurrentRequests: 2,
                defaultUserAgent: "WordZMac Update Checker"
            )
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        return NativeAPIClient(
            session: URLSession(configuration: configuration),
            retryPolicy: NativeAPIRetryPolicy(maxRetries: 1, baseDelayNanoseconds: 150_000_000),
            maxConcurrentRequests: 2,
            defaultUserAgent: "WordZMac Update Checker"
        )
    }

    static func updateCheckError(from error: NativeAPIClientError) -> Error {
        switch error {
        case .httpStatus(let code, let data, _, _):
            let apiMessage = GitHubReleasePayloadParser.errorMessage(from: data)
            let description = apiMessage?.isEmpty == false
                ? apiMessage!
                : "检查更新失败（HTTP \(code)）。"
            return NSError(
                domain: "WordZMac.GitHubReleaseUpdateService",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: description]
            )
        case .invalidResponse:
            return NSError(domain: "WordZMac.GitHubReleaseUpdateService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法解析更新响应。"
            ])
        case .transport:
            return error
        }
    }
}
