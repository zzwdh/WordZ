import Foundation

enum NativeDiagnosticsRedactionSupport {
    private static let redactedPrefix = "<redacted>"

    static func redactPath(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard trimmed.contains("/") || trimmed.hasPrefix("file://") else { return trimmed }

        let normalizedPath: String
        if trimmed.hasPrefix("file://"),
           let url = URL(string: trimmed),
           url.isFileURL {
            normalizedPath = url.path
        } else {
            normalizedPath = trimmed
        }

        let url = URL(fileURLWithPath: normalizedPath)
        let lastComponent = url.lastPathComponent.isEmpty
            ? url.deletingLastPathComponent().lastPathComponent
            : url.lastPathComponent
        guard !lastComponent.isEmpty else {
            return redactedPrefix
        }
        return "\(redactedPrefix)/\(lastComponent)"
    }
}

extension RecentDocumentItem {
    func redactedForDiagnostics() -> RecentDocumentItem {
        RecentDocumentItem(
            id: id,
            corpusID: corpusID,
            title: title,
            subtitle: subtitle,
            representedPath: NativeDiagnosticsRedactionSupport.redactPath(representedPath),
            lastOpenedAt: lastOpenedAt
        )
    }
}

extension PersistedNativeBackgroundTaskAction {
    func redactedForDiagnostics() -> PersistedNativeBackgroundTaskAction {
        switch action {
        case .openFile(let path):
            return PersistedNativeBackgroundTaskAction(kind: kind, value: NativeDiagnosticsRedactionSupport.redactPath(path))
        case .installDownloadedUpdate(let path):
            return PersistedNativeBackgroundTaskAction(kind: kind, value: NativeDiagnosticsRedactionSupport.redactPath(path))
        case .openURL, .cancelTask, .none:
            return self
        }
    }
}

extension PersistedNativeBackgroundTaskItem {
    func redactedForDiagnostics() -> PersistedNativeBackgroundTaskItem {
        PersistedNativeBackgroundTaskItem(
            id: id,
            title: title,
            detail: detail,
            state: state,
            progress: progress,
            startedAt: startedAt,
            updatedAt: updatedAt,
            primaryAction: primaryAction?.redactedForDiagnostics()
        )
    }
}

extension NativeHostPreferencesSnapshot {
    func redactedForDiagnostics() -> NativeHostPreferencesSnapshot {
        NativeHostPreferencesSnapshot(
            languageMode: languageMode,
            autoUpdateEnabled: autoUpdateEnabled,
            checkForUpdatesOnLaunch: checkForUpdatesOnLaunch,
            autoDownloadUpdates: autoDownloadUpdates,
            recentDocuments: recentDocuments.map { $0.redactedForDiagnostics() },
            lastUpdateCheckAt: lastUpdateCheckAt,
            lastUpdateStatus: lastUpdateStatus,
            downloadedUpdateVersion: downloadedUpdateVersion,
            downloadedUpdateName: downloadedUpdateName,
            downloadedUpdatePath: NativeDiagnosticsRedactionSupport.redactPath(downloadedUpdatePath),
            taskHistory: taskHistory.map { $0.redactedForDiagnostics() }
        )
    }
}

extension NativeBuildMetadata {
    func redactedForDiagnostics() -> NativeBuildMetadata {
        NativeBuildMetadata(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            version: version,
            buildNumber: buildNumber,
            architecture: architecture,
            builtAt: builtAt,
            gitCommit: gitCommit,
            gitBranch: gitBranch,
            distributionChannel: distributionChannel,
            executableSHA256: executableSHA256,
            bundlePath: NativeDiagnosticsRedactionSupport.redactPath(bundlePath),
            executablePath: NativeDiagnosticsRedactionSupport.redactPath(executablePath),
            sourceLabel: sourceLabel
        )
    }
}

extension NativeDiagnosticsBundleContext {
    func redactedForDiagnostics() -> NativeDiagnosticsBundleContext {
        NativeDiagnosticsBundleContext(
            generatedAt: generatedAt,
            appName: appName,
            versionLabel: versionLabel,
            buildSummary: buildSummary,
            workspaceSummary: workspaceSummary,
            activeTab: activeTab,
            selectedFolderName: selectedFolderName,
            selectedCorpusName: selectedCorpusName,
            engineEntryPath: NativeDiagnosticsRedactionSupport.redactPath(engineEntryPath),
            runtimeWorkingDirectory: NativeDiagnosticsRedactionSupport.redactPath(runtimeWorkingDirectory),
            userDataDirectory: NativeDiagnosticsRedactionSupport.redactPath(userDataDirectory),
            taskCenterSummary: taskCenterSummary,
            runningTaskCount: runningTaskCount,
            persistedTaskCount: persistedTaskCount
        )
    }
}
