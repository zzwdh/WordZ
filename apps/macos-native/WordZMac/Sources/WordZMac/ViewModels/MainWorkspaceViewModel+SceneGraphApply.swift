import Foundation

struct RootSceneBuildRequest: Equatable {
    let windowTitle: String
    let selectedTab: WorkspaceDetailTab
    let languageMode: AppLanguageMode
}

struct WelcomeSceneBuildRequest: Equatable {
    let title: String
    let subtitle: String
    let workspaceSummary: String
    let canOpenSelection: Bool
    let recentDocuments: [RecentDocumentItem]
    let releaseNotes: [String]
    let help: [String]
}

@MainActor
extension MainWorkspaceViewModel {
    func applySyncedGraph(rebuildRootScene: Bool, rebuildWelcomeScene: Bool) {
        let nextSceneGraph = sceneGraphStore.graph
        let nextSceneGraphRevision = sceneGraphStore.graphRevision
        if lastAppliedSceneGraphRevision != nextSceneGraphRevision {
            sceneGraph = nextSceneGraph
            lastAppliedSceneGraphRevision = nextSceneGraphRevision
        }
        if rebuildRootScene {
            syncRootScene()
        }
        if rebuildWelcomeScene {
            syncWelcomeScene()
        }
    }

    private func syncRootScene() {
        let request = RootSceneBuildRequest(
            windowTitle: windowTitle,
            selectedTab: selectedTab,
            languageMode: settings.languageMode
        )
        guard lastRootSceneBuildRequest != request else { return }
        lastRootSceneBuildRequest = request

        let nextRootScene = rootSceneBuilder.build(
            windowTitle: request.windowTitle,
            activeTab: request.selectedTab,
            languageMode: request.languageMode
        )
        if rootScene != nextRootScene {
            rootScene = nextRootScene
        }
    }
}
