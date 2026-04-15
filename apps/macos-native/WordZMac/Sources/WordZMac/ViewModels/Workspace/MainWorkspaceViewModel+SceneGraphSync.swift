import Foundation

struct SceneSyncRequest: Equatable {
    let plan: SceneSyncPlan
    let resultTab: WorkspaceDetailTab?

    func merged(with other: SceneSyncRequest) -> SceneSyncRequest {
        let mergedPlan = plan.merged(with: other.plan)
        let mergedResultTab: WorkspaceDetailTab?
        if mergedPlan.mutations.contains(.resultContent) {
            mergedResultTab = other.resultTab ?? resultTab
        } else {
            mergedResultTab = nil
        }
        return SceneSyncRequest(plan: mergedPlan, resultTab: mergedResultTab)
    }
}

@MainActor
extension MainWorkspaceViewModel {
    func requestSceneSync(_ request: SceneSyncRequest) {
        if isApplyingSceneSyncRequest {
            pendingSceneSyncRequest = pendingSceneSyncRequest?.merged(with: request) ?? request
            return
        }

        isApplyingSceneSyncRequest = true
        defer { isApplyingSceneSyncRequest = false }

        var currentRequest: SceneSyncRequest? = request
        while let request = currentRequest {
            applySceneSyncPlanNow(request)
            if let pending = pendingSceneSyncRequest {
                pendingSceneSyncRequest = nil
                currentRequest = pending
            } else {
                currentRequest = nil
            }
        }
    }

    private func applySceneSyncPlanNow(_ request: SceneSyncRequest) {
        let plan = request.plan
        if plan.syncWorkflowLibraryState {
            syncWorkflowLibraryState()
        }

        mutateSceneGraph(plan.mutations, resultTab: request.resultTab)

        if plan.refreshChromeState {
            refreshShellAvailability(using: sceneGraphStore.graph, selectedTab: selectedTab)
            sceneGraphStore.updateGraph(
                sidebar: sidebar.scene,
                shell: shell.scene,
                activeTab: selectedTab
            )
        }

        applySyncedGraph(
            rebuildRootScene: plan.rebuildRootScene,
            rebuildWelcomeScene: plan.rebuildWelcomeScene
        )
    }

    func syncResultContentSceneGraph(
        for resultTab: WorkspaceDetailTab? = nil,
        rebuildRootScene: Bool = false
    ) {
        requestSceneSync(
            SceneSyncRequest(
                plan: .init(
                    mutations: [.resultContent],
                    syncWorkflowLibraryState: false,
                    refreshChromeState: true,
                    rebuildRootScene: rebuildRootScene,
                    rebuildWelcomeScene: false
                ),
                resultTab: resultTab
            )
        )
    }

    private func mutateSceneGraph(
        _ mutations: SceneGraphMutationSet,
        resultTab: WorkspaceDetailTab? = nil
    ) {
        let mutations = mutations.normalized
        if mutations.contains(.full) {
            sceneGraphStore.sync(
                context: sceneStore.context,
                sidebar: sidebar.scene,
                shell: shell.scene,
                library: library.scene,
                settings: settings.scene,
                activeTab: selectedTab,
                word: word.scene,
                tokenize: tokenize.scene,
                stats: stats.scene,
                topics: topics.scene,
                compare: compare.scene,
                sentiment: sentiment.scene,
                keyword: keyword.scene,
                chiSquare: chiSquare.scene,
                plot: plot.scene,
                ngram: ngram.scene,
                cluster: cluster.scene,
                kwic: kwic.scene,
                collocate: collocate.scene,
                locator: locator.scene
            )
            return
        }

        if mutations.contains(.settings) {
            sceneGraphStore.syncSettings(settings.scene)
        }

        if mutations.contains(.librarySelection) {
            sceneGraphStore.syncSidebarAndLibrary(
                sidebar: sidebar.scene,
                library: library.scene,
                shell: shell.scene,
                activeTab: selectedTab
            )
        } else if mutations.contains(.navigation) {
            sceneGraphStore.syncShellNavigation(shell: shell.scene, activeTab: selectedTab)
        }

        if mutations.contains(.resultContent) {
            sceneGraphStore.syncResult(
                shell: shell.scene,
                activeTab: selectedTab,
                resultTab: resultTab ?? shell.selectedTab,
                word: word.scene,
                tokenize: tokenize.scene,
                stats: stats.scene,
                topics: topics.scene,
                compare: compare.scene,
                sentiment: sentiment.scene,
                keyword: keyword.scene,
                chiSquare: chiSquare.scene,
                plot: plot.scene,
                ngram: ngram.scene,
                cluster: cluster.scene,
                kwic: kwic.scene,
                collocate: collocate.scene,
                locator: locator.scene
            )
        }
    }
}
