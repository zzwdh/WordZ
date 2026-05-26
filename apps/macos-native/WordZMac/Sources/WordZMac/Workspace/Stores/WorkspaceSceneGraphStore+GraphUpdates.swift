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
        let changedFields = WorkspaceSceneGraphChangedFields(
            context: sceneFieldChanged(context, from: current.context),
            sidebar: sceneFieldChanged(sidebar, from: current.sidebar),
            shell: sceneFieldChanged(shell, from: current.shell),
            library: sceneFieldChanged(library, from: current.library),
            settings: sceneFieldChanged(settings, from: current.settings),
            activeTab: sceneFieldChanged(activeTab, from: current.activeTab),
            word: sceneFieldChanged(word, from: current.word),
            tokenize: sceneFieldChanged(tokenize, from: current.tokenize),
            stats: sceneFieldChanged(stats, from: current.stats),
            topics: sceneFieldChanged(topics, from: current.topics),
            compare: sceneFieldChanged(compare, from: current.compare),
            sentiment: sceneFieldChanged(sentiment, from: current.sentiment),
            keyword: sceneFieldChanged(keyword, from: current.keyword),
            chiSquare: sceneFieldChanged(chiSquare, from: current.chiSquare),
            plot: sceneFieldChanged(plot, from: current.plot),
            ngram: sceneFieldChanged(ngram, from: current.ngram),
            cluster: sceneFieldChanged(cluster, from: current.cluster),
            kwic: sceneFieldChanged(kwic, from: current.kwic),
            collocate: sceneFieldChanged(collocate, from: current.collocate),
            locator: sceneFieldChanged(locator, from: current.locator)
        )
        guard changedFields.hasChanges else { return }

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
        ), changedFields: changedFields)
    }
}

private func sceneFieldChanged<Value: Equatable>(_ next: Value?, from current: Value) -> Bool {
    guard let next else { return false }
    return next != current
}
