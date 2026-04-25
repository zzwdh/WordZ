import Foundation
import WordZEngine

@MainActor
extension MainWorkspaceViewModel {
    var currentVersionForUpdateChecks: String {
        if let appVersion = sceneStore.appInfoSnapshot?.version.trimmingCharacters(in: .whitespacesAndNewlines),
           !appVersion.isEmpty {
            return appVersion
        }
        let buildVersion = buildMetadataProvider.current().version.trimmingCharacters(in: .whitespacesAndNewlines)
        if !buildVersion.isEmpty {
            return buildVersion
        }
        return EnginePaths.releaseVersion()
    }

    func applyUpdateStateSnapshot(_ snapshot: NativeUpdateStateSnapshot) {
        updateState = snapshot
        settings.applyUpdateState(snapshot)
        menuBarStatus.applyUpdateState(snapshot)
    }

    func makeUpdateStateSnapshot(
        from result: NativeUpdateCheckResult? = nil,
        preferences: NativeHostPreferencesSnapshot? = nil,
        statusMessage: String? = nil,
        isChecking: Bool = false,
        isDownloading: Bool = false,
        downloadProgress: Double? = nil
    ) -> NativeUpdateStateSnapshot {
        let currentPreferences = preferences ?? hostPreferencesStore.load()
        let resolvedResult = result ?? latestCheckedUpdate
        return NativeUpdateStateSnapshot(
            currentVersion: resolvedResult?.currentVersion ?? currentVersionForUpdateChecks,
            latestVersion: resolvedResult?.latestVersion ?? updateState.latestVersion,
            releaseURL: resolvedResult?.releaseURL ?? updateState.releaseURL,
            statusMessage: statusMessage ?? resolvedResult?.statusMessage ?? updateState.statusMessage,
            updateAvailable: resolvedResult?.updateAvailable ?? updateState.updateAvailable,
            isChecking: isChecking,
            isDownloading: isDownloading,
            downloadProgress: downloadProgress,
            downloadedUpdateVersion: currentPreferences.downloadedUpdateVersion,
            downloadedUpdateName: currentPreferences.downloadedUpdateName,
            downloadedUpdatePath: currentPreferences.downloadedUpdatePath,
            releaseTitle: resolvedResult?.releaseTitle ?? updateState.releaseTitle,
            publishedAt: resolvedResult?.publishedAt ?? updateState.publishedAt,
            releaseNotes: resolvedResult?.releaseNotes ?? updateState.releaseNotes,
            assetName: resolvedResult?.asset?.name ?? updateState.assetName
        )
    }
}
