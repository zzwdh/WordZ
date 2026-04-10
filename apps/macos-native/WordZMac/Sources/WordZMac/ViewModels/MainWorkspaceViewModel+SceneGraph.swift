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

    func ensureSelectedResultSceneIsReady() {
        switch selectedTab {
        case .stats:
            stats.rebuildSceneIfNeeded()
        case .word:
            word.rebuildSceneIfNeeded()
        default:
            break
        }
    }

    func syncVisibleResultSceneIfNeeded(_ tab: WorkspaceDetailTab) {
        guard selectedTab == tab else { return }
        syncResultContentSceneGraph(for: tab)
    }
}
