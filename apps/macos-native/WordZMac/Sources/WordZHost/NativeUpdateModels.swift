import Foundation

package struct NativeUpdateAsset: Equatable {
    package let name: String
    package let downloadURL: String

    package init(name: String, downloadURL: String) {
        self.name = name
        self.downloadURL = downloadURL
    }
}

package struct NativeUpdateCheckResult: Equatable {
    package let currentVersion: String
    package let latestVersion: String
    package let releaseURL: String
    package let statusMessage: String
    package let updateAvailable: Bool
    package let asset: NativeUpdateAsset?
    package let releaseTitle: String
    package let publishedAt: String
    package let releaseNotes: [String]

    package init(
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

package struct NativeDownloadedUpdate: Equatable {
    package let version: String
    package let assetName: String
    package let localPath: String
    package let releaseURL: String

    package init(version: String, assetName: String, localPath: String, releaseURL: String) {
        self.version = version
        self.assetName = assetName
        self.localPath = localPath
        self.releaseURL = releaseURL
    }
}

package protocol NativeUpdateDownloading {
    func download(
        from remoteURL: URL,
        to destinationURL: URL,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> URL
}

@MainActor
package protocol NativeUpdateServicing: AnyObject {
    func checkForUpdates(currentVersion: String) async throws -> NativeUpdateCheckResult
    func downloadUpdate(
        _ update: NativeUpdateCheckResult,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> NativeDownloadedUpdate
}
