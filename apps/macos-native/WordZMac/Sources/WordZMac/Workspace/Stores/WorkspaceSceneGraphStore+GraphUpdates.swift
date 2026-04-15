import Foundation

@MainActor
extension WorkspaceSceneGraphStore {
    func updateGraph(
        context: WorkspaceSceneContext? = nil,
        sidebar: WorkspaceSidebarSceneModel? = nil,
        shell: WorkspaceShellSceneModel? = nil,
        library: LibraryManagementSceneModel? = nil,
        settings: SettingsPaneSceneModel? = nil,
        activeTab: WorkspaceDetailTab? = nil,
        word: WorkspaceResultSceneNode? = nil,
        tokenize: WorkspaceResultSceneNode? = nil,
        stats: WorkspaceResultSceneNode? = nil,
        topics: WorkspaceResultSceneNode? = nil,
        compare: WorkspaceResultSceneNode? = nil,
        sentiment: WorkspaceResultSceneNode? = nil,
        keyword: WorkspaceResultSceneNode? = nil,
        chiSquare: WorkspaceResultSceneNode? = nil,
        plot: WorkspaceResultSceneNode? = nil,
        ngram: WorkspaceResultSceneNode? = nil,
        cluster: WorkspaceResultSceneNode? = nil,
        kwic: WorkspaceResultSceneNode? = nil,
        collocate: WorkspaceResultSceneNode? = nil,
        locator: WorkspaceResultSceneNode? = nil
    ) {
        let current = graph
        guard sceneFieldChanged(context, from: current.context) ||
                sceneFieldChanged(sidebar, from: current.sidebar) ||
                sceneFieldChanged(shell, from: current.shell) ||
                sceneFieldChanged(library, from: current.library) ||
                sceneFieldChanged(settings, from: current.settings) ||
                sceneFieldChanged(activeTab, from: current.activeTab) ||
                sceneFieldChanged(word, from: current.word) ||
                sceneFieldChanged(tokenize, from: current.tokenize) ||
                sceneFieldChanged(stats, from: current.stats) ||
                sceneFieldChanged(topics, from: current.topics) ||
                sceneFieldChanged(compare, from: current.compare) ||
                sceneFieldChanged(sentiment, from: current.sentiment) ||
                sceneFieldChanged(keyword, from: current.keyword) ||
                sceneFieldChanged(chiSquare, from: current.chiSquare) ||
                sceneFieldChanged(plot, from: current.plot) ||
                sceneFieldChanged(ngram, from: current.ngram) ||
                sceneFieldChanged(cluster, from: current.cluster) ||
                sceneFieldChanged(kwic, from: current.kwic) ||
                sceneFieldChanged(collocate, from: current.collocate) ||
                sceneFieldChanged(locator, from: current.locator)
        else {
            return
        }

        applyGraph(WorkspaceSceneGraph(
            context: context ?? graph.context,
            sidebar: sidebar ?? graph.sidebar,
            shell: shell ?? graph.shell,
            library: library ?? graph.library,
            settings: settings ?? graph.settings,
            activeTab: activeTab ?? graph.activeTab,
            word: word ?? graph.word,
            tokenize: tokenize ?? graph.tokenize,
            stats: stats ?? graph.stats,
            topics: topics ?? graph.topics,
            compare: compare ?? graph.compare,
            sentiment: sentiment ?? graph.sentiment,
            keyword: keyword ?? graph.keyword,
            chiSquare: chiSquare ?? graph.chiSquare,
            plot: plot ?? graph.plot,
            ngram: ngram ?? graph.ngram,
            cluster: cluster ?? graph.cluster,
            kwic: kwic ?? graph.kwic,
            collocate: collocate ?? graph.collocate,
            locator: locator ?? graph.locator
        ))
    }
}

private func sceneFieldChanged<Value: Equatable>(_ next: Value?, from current: Value) -> Bool {
    guard let next else { return false }
    return next != current
}
