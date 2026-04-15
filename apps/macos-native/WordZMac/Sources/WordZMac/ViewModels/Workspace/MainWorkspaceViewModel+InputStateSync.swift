import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func showWelcomeIfNeeded() {
        // The welcome sheet is currently unstable on launch and can cover the
        // main workspace with a blank modal surface. Keep manual invocation
        // available, but don't auto-present it until the sheet path is fixed.
        isWelcomePresented = false
    }

    func cancelPendingInputStateSync() {
        inputChangeSyncTask?.cancel()
        inputChangeSyncTask = nil
    }

    func scheduleInputStateSync() {
        cancelPendingInputStateSync()
        inputChangeSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.performInputStateSync()
            }
        }
    }

    private func performInputStateSync() {
        flowCoordinator.markInputStateEdited(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func syncWelcomeScene() {
        let request = WelcomeSceneBuildRequest(
            title: sceneStore.context.appName,
            subtitle: sceneStore.context.versionLabel,
            workspaceSummary: sceneStore.context.workspaceSummary,
            canOpenSelection: sidebar.selectedCorpusID != nil,
            recentDocuments: settings.scene.recentDocuments,
            releaseNotes: settings.scene.releaseNotes,
            help: settings.scene.help
        )
        guard lastWelcomeSceneBuildRequest != request else { return }
        lastWelcomeSceneBuildRequest = request

        let nextScene = WelcomeSceneModel(
            title: request.title,
            subtitle: request.subtitle,
            workspaceSummary: request.workspaceSummary,
            canOpenSelection: request.canOpenSelection,
            recentDocuments: request.recentDocuments,
            releaseNotes: request.releaseNotes,
            help: request.help
        )
        if welcomeScene != nextScene {
            welcomeScene = nextScene
        }
    }
}
