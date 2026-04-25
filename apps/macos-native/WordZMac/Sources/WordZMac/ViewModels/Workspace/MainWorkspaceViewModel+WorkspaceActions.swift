import Foundation

private let lifecycleLogger = WordZTelemetry.logger(category: "Lifecycle")

@MainActor
extension MainWorkspaceViewModel {
    func initializeIfNeeded() async {
        guard !initialized else {
            lifecycleLogger.debug("initializeIfNeeded.skippedAlreadyInitialized")
            return
        }
        let startedAt = Date()
        lifecycleLogger.info("initializeIfNeeded.started")
        cancelPendingInputStateSync()
        initialized = true
        await performWithoutSceneSyncCallbacks {
            await appCoordinator.refreshAll(features: features)
        }
        restoreWorkspaceAnnotationState(from: sessionStore.workspaceSnapshot)
        await reloadAnalysisPresets()
        syncSceneGraph()
        showWelcomeIfNeeded()
        scheduleLaunchUpdateCheckIfNeeded()
        lifecycleLogger.info(
            "initializeIfNeeded.completed durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public) presets=\(self.analysisPresets.count, privacy: .public)"
        )
    }

    func refreshAll() async {
        let startedAt = Date()
        lifecycleLogger.info("workspaceRefresh.started")
        cancelPendingInputStateSync()
        await performWithoutSceneSyncCallbacks {
            await appCoordinator.refreshAll(features: features)
        }
        restoreWorkspaceAnnotationState(from: sessionStore.workspaceSnapshot)
        await reloadAnalysisPresets()
        syncSceneGraph()
        showWelcomeIfNeeded()
        scheduleLaunchUpdateCheckIfNeeded()
        lifecycleLogger.info(
            "workspaceRefresh.completed durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public) presets=\(self.analysisPresets.count, privacy: .public)"
        )
    }

    func openSelectedCorpus() async {
        cancelPendingInputStateSync()
        await flowCoordinator.openSelectedCorpus(features: features)
        syncSceneGraph(source: .librarySelection)
    }

    func saveSettings() async {
        await flowCoordinator.saveSettings(features: features)
        syncSceneGraph(source: .settings)
    }

    func clearRecentDocuments() async {
        do {
            let snapshot = try hostPreferencesStore.clearRecentDocuments()
            settings.applyHostPreferences(snapshot, preservingRuntimeUpdatePolicy: true)
            try await hostActionService.clearRecentDocuments()
            settings.setSupportStatus(t("已清除最近打开记录。", "Cleared recent documents."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法清除最近记录", titleEn: "Unable to Clear Recent Documents")
        }
    }

    func newWorkspace() async {
        cancelPendingInputStateSync()
        await performWithoutSceneSyncCallbacks {
            await flowCoordinator.newWorkspace(features: features)
        }
        restoreWorkspaceAnnotationState(from: sessionStore.workspaceSnapshot)
        syncSceneGraph(source: .full)
        clearActiveIssue()
    }

    func restoreSavedWorkspace() async {
        cancelPendingInputStateSync()
        await performWithoutSceneSyncCallbacks {
            await flowCoordinator.restoreSavedWorkspace(features: features)
        }
        restoreWorkspaceAnnotationState(from: sessionStore.workspaceSnapshot)
        syncSceneGraph(source: .full)
        clearActiveIssue()
    }

    func openRecentDocument(_ corpusID: String) async {
        cancelPendingInputStateSync()
        guard sidebar.librarySnapshot.corpora.contains(where: { $0.id == corpusID }) else {
            let message = t("最近打开记录对应的语料已不存在。", "The corpus referenced by this recent item no longer exists.")
            settings.setSupportStatus(message)
            activeIssue = WorkspaceIssueBanner(
                tone: .warning,
                title: t("无法重新打开最近项目", "Unable to Reopen Recent Item"),
                message: message,
                recoveryAction: .refreshWorkspace
            )
            return
        }
        sidebar.setSelectedCorpusID(corpusID, notifySelectionChange: false)
        library.selectCorpus(corpusID)
        flowCoordinator.prepareCorpusSelectionChange(features: features)
        await openSelectedCorpus()
        isWelcomePresented = false
        clearActiveIssue()
    }

    func handleExternalPaths(_ paths: [String]) async {
        guard !paths.isEmpty else { return }
        cancelPendingInputStateSync()
        await flowCoordinator.importExternalPaths(paths, features: features)
        syncSceneGraph(source: .full)
        isWelcomePresented = false
        clearActiveIssue()
    }

    func importCorpusFromDialog(preferredWindowRoute: NativeWindowRoute? = nil) async {
        cancelPendingInputStateSync()
        await flowCoordinator.importCorpusFromDialog(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncSceneGraph(source: .full)
        isWelcomePresented = false
        clearActiveIssue()
    }

    func refreshLibraryManagement() async {
        await flowCoordinator.refreshLibraryManagement(features: features)
        syncSceneGraph()
    }

    func handleLibraryAction(
        _ action: LibraryManagementAction,
        preferredWindowRoute: NativeWindowRoute? = nil
    ) async {
        await flowCoordinator.handleLibraryAction(
            action,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncSceneGraph(source: .full)
    }

    func shutdown() async {
        cancelPendingInputStateSync()
        await appCoordinator.shutdown()
    }
}
