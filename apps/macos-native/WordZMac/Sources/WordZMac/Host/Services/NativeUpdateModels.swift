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

protocol NativeUpdateDownloading {
    func download(
        from remoteURL: URL,
        to destinationURL: URL,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> URL
}

@MainActor
protocol NativeUpdateServicing: AnyObject {
    func checkForUpdates(currentVersion: String) async throws -> NativeUpdateCheckResult
    func downloadUpdate(
        _ update: NativeUpdateCheckResult,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> NativeDownloadedUpdate
}
