import Foundation

struct NativeUpdateAsset: Equatable {
    let name: String
    let downloadURL: String
}

struct NativeUpdateCheckResult: Equatable {
    let currentVersion: String
    let latestVersion: String
    let releaseURL: String
    let statusMessage: String
    let updateAvailable: Bool
    let asset: NativeUpdateAsset?
    let releaseTitle: String
    let publishedAt: String
    let releaseNotes: [String]

    init(
        currentVersion: String,
        latestVersion: String,
        releaseURL: String,
        statusMessage: String,
        updateAvailable: Bool,
        asset: NativeUpdateAsset?,
        releaseTitle: String = "",
        publishedAt: String = "",
        releaseNotes: [String] = []
    ) {
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.releaseURL = releaseURL
        self.statusMessage = statusMessage
        self.updateAvailable = updateAvailable
        self.asset = asset
        self.releaseTitle = releaseTitle
        self.publishedAt = publishedAt
        self.releaseNotes = releaseNotes
    }
}

struct NativeDownloadedUpdate: Equatable {
    let version: String
    let assetName: String
    let localPath: String
    let releaseURL: String
}

@MainActor
protocol NativeUpdateServicing: AnyObject {
    func checkForUpdates(currentVersion: String) async throws -> NativeUpdateCheckResult
    func downloadUpdate(
        _ update: NativeUpdateCheckResult,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> NativeDownloadedUpdate
}

struct ReleaseVersionComparator {
    static func isNewer(_ latest: String, than current: String) -> Bool {
        let latestParts = normalizedParts(for: latest)
        let currentParts = normalizedParts(for: current)
        let maxCount = max(latestParts.count, currentParts.count)
        for index in 0..<maxCount {
            let lhs = index < latestParts.count ? latestParts[index] : 0
            let rhs = index < currentParts.count ? currentParts[index] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }
        return false
    }

    private static func normalizedParts(for version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "")
            .split(separator: ".")
            .compactMap { Int($0.filter(\.isNumber)) }
    }
}

enum GitHubReleaseAssetSelector {
    static func preferredAsset(from assets: [NativeUpdateAsset]) -> NativeUpdateAsset? {
        let installables = assets.filter { asset in
            let lowercased = asset.name.lowercased()
            return lowercased.hasSuffix(".dmg") || lowercased.hasSuffix(".zip")
        }
        guard !installables.isEmpty else { return nil }

        #if arch(arm64)
        let architectureHints = ["universal", "arm64", "apple-silicon", "mac"]
        #else
        let architectureHints = ["universal", "x86_64", "intel", "mac"]
        #endif

        for hint in architectureHints {
            if let matched = installables.first(where: { $0.name.lowercased().contains(hint) }) {
                return matched
            }
        }

        if let dmg = installables.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) {
            return dmg
        }
        return installables.first
    }
}

enum GitHubReleasePayloadParser {
    static func parse(_ object: [String: Any], currentVersion: String) -> NativeUpdateCheckResult {
        let latestVersion = (object["tag_name"] as? String)
            ?? (object["name"] as? String)
            ?? currentVersion
        let releaseTitle = (object["name"] as? String) ?? latestVersion
        let releaseURL = (object["html_url"] as? String) ?? "https://github.com/zzwdh/WordZ/releases"
        let publishedAt = (object["published_at"] as? String) ?? ""
        let updateAvailable = ReleaseVersionComparator.isNewer(latestVersion, than: currentVersion)
        let assets = ((object["assets"] as? [[String: Any]]) ?? []).compactMap { assetObject -> NativeUpdateAsset? in
            let name = (assetObject["name"] as? String) ?? ""
            let downloadURL = (assetObject["browser_download_url"] as? String) ?? ""
            guard !name.isEmpty, !downloadURL.isEmpty else { return nil }
            return NativeUpdateAsset(name: name, downloadURL: downloadURL)
        }
        let asset = GitHubReleaseAssetSelector.preferredAsset(from: assets)
        let notes = normalizedReleaseNotes(from: (object["body"] as? String) ?? "")
        let statusMessage: String
        if updateAvailable {
            if let asset {
                statusMessage = "发现新版本 \(latestVersion)，可下载更新包 \(asset.name)。"
            } else {
                statusMessage = "发现新版本 \(latestVersion)，但当前没有可下载的 mac 安装包。"
            }
        } else {
            statusMessage = "当前已是最新版本（\(currentVersion)）。"
        }

        return NativeUpdateCheckResult(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseURL: releaseURL,
            statusMessage: statusMessage,
            updateAvailable: updateAvailable,
            asset: asset,
            releaseTitle: releaseTitle,
            publishedAt: publishedAt,
            releaseNotes: notes
        )
    }

    static func normalizedReleaseNotes(from body: String) -> [String] {
        body
            .components(separatedBy: .newlines)
            .map { line in
                var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                while let first = cleaned.first, ["#", "-", "*", "+"].contains(first) {
                    cleaned.removeFirst()
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return cleaned
            }
            .filter { !$0.isEmpty }
    }
}

private final class UpdateDownloadBridge: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let onProgress: @MainActor (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var hasFinished = false

    init(destinationURL: URL, onProgress: @escaping @MainActor (Double) -> Void) {
        self.destinationURL = destinationURL
        self.onProgress = onProgress
    }

    func run(downloadURL: URL, configuration: URLSessionConfiguration) async throws -> URL {
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: downloadURL).resume()
        }
    }

    func urlSession(
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

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard !hasFinished else { return }
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

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !hasFinished, let error else { return }
        hasFinished = true
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

final class GitHubReleaseUpdateService: NativeUpdateServicing {
    private let session: URLSession
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/zzwdh/WordZ/releases/latest")!

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 5
            configuration.timeoutIntervalForResource = 10
            self.session = URLSession(configuration: configuration)
        }
    }

    func checkForUpdates(currentVersion: String) async throws -> NativeUpdateCheckResult {
        let (data, _) = try await session.data(from: latestReleaseURL)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw NSError(domain: "WordZMac.GitHubReleaseUpdateService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法解析更新响应。"
            ])
        }

        return GitHubReleasePayloadParser.parse(object, currentVersion: currentVersion)
    }

    func downloadUpdate(
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

        let updatesDirectory = EnginePaths.defaultUserDataURL()
            .appendingPathComponent("downloads", isDirectory: true)
            .appendingPathComponent("updates", isDirectory: true)
        let destinationURL = updatesDirectory.appendingPathComponent(asset.name)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 600
        let bridge = UpdateDownloadBridge(destinationURL: destinationURL, onProgress: onProgress)
        let localURL = try await bridge.run(downloadURL: remoteURL, configuration: configuration)
        return NativeDownloadedUpdate(
            version: update.latestVersion,
            assetName: asset.name,
            localPath: localURL.path,
            releaseURL: update.releaseURL
        )
    }
}
