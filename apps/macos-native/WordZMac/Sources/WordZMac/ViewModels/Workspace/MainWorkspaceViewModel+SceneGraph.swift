import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func updateFrequencyMetricDefinition(_ definition: FrequencyMetricDefinition) {
        stats.applyFrequencyMetricDefinition(definition)
        word.applyFrequencyMetricDefinition(definition)
        flowCoordinator.markWorkspaceEdited(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func syncSceneGraph(source: SceneSyncSource = .full) {
        requestSceneSync(
            SceneSyncRequest(plan: source.plan, resultTab: nil)
        )
    }

    func ensureSelectedResultSceneIsReady() -> Bool {
        switch selectedTab {
        case .stats:
            let hasPendingSceneRebuild = stats.hasPendingSceneRebuild
            stats.rebuildSceneIfNeeded()
            return hasPendingSceneRebuild
        case .word:
            let hasPendingSceneRebuild = word.hasPendingSceneRebuild
            word.rebuildSceneIfNeeded()
            return hasPendingSceneRebuild
        default:
            return false
        }
    }

    func syncVisibleResultSceneIfNeeded(_ tab: WorkspaceDetailTab) {
        guard selectedTab == tab else { return }
        syncResultContentSceneGraph(for: tab)
    }
}
