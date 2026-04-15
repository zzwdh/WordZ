import Foundation

@MainActor
extension WorkspaceSceneGraphStore {
    func sync(
        context: WorkspaceSceneContext,
        sidebar: WorkspaceSidebarSceneModel,
        shell: WorkspaceShellSceneModel,
        library: LibraryManagementSceneModel,
        settings: SettingsPaneSceneModel,
        activeTab: WorkspaceDetailTab,
        word: WordSceneModel? = nil,
        tokenize: TokenizeSceneModel? = nil,
        stats: StatsSceneModel?,
        topics: TopicsSceneModel? = nil,
        compare: CompareSceneModel?,
        sentiment: SentimentSceneModel? = nil,
        keyword: KeywordSceneModel? = nil,
        chiSquare: ChiSquareSceneModel?,
        plot: PlotSceneModel? = nil,
        ngram: NgramSceneModel?,
        cluster: ClusterSceneModel? = nil,
        kwic: KWICSceneModel?,
        collocate: CollocateSceneModel?,
        locator: LocatorSceneModel?
    ) {
        let resultNodes = buildResultNodes(
            word: word,
            tokenize: tokenize,
            stats: stats,
            topics: topics,
            compare: compare,
            sentiment: sentiment,
            keyword: keyword,
            chiSquare: chiSquare,
            plot: plot,
            ngram: ngram,
            cluster: cluster,
            kwic: kwic,
            collocate: collocate,
            locator: locator
        )
        updateGraph(
            context: context,
            sidebar: sidebar,
            shell: shell,
            library: library,
            settings: settings,
            activeTab: activeTab,
            word: resultNodes.word,
            tokenize: resultNodes.tokenize,
            stats: resultNodes.stats,
            topics: resultNodes.topics,
            compare: resultNodes.compare,
            sentiment: resultNodes.sentiment,
            keyword: resultNodes.keyword,
            chiSquare: resultNodes.chiSquare,
            plot: resultNodes.plot,
            ngram: resultNodes.ngram,
            cluster: resultNodes.cluster,
            kwic: resultNodes.kwic,
            collocate: resultNodes.collocate,
            locator: resultNodes.locator
        )
    }

    func syncResults(
        shell: WorkspaceShellSceneModel? = nil,
        activeTab: WorkspaceDetailTab,
        word: WordSceneModel? = nil,
        tokenize: TokenizeSceneModel? = nil,
        stats: StatsSceneModel?,
        topics: TopicsSceneModel? = nil,
        compare: CompareSceneModel?,
        sentiment: SentimentSceneModel? = nil,
        keyword: KeywordSceneModel? = nil,
        chiSquare: ChiSquareSceneModel?,
        plot: PlotSceneModel? = nil,
        ngram: NgramSceneModel?,
        cluster: ClusterSceneModel? = nil,
        kwic: KWICSceneModel?,
        collocate: CollocateSceneModel?,
        locator: LocatorSceneModel?
    ) {
        let resultNodes = buildResultNodes(
            word: word,
            tokenize: tokenize,
            stats: stats,
            topics: topics,
            compare: compare,
            sentiment: sentiment,
            keyword: keyword,
            chiSquare: chiSquare,
            plot: plot,
            ngram: ngram,
            cluster: cluster,
            kwic: kwic,
            collocate: collocate,
            locator: locator
        )
        updateGraph(
            shell: shell,
            activeTab: activeTab,
            word: resultNodes.word,
            tokenize: resultNodes.tokenize,
            stats: resultNodes.stats,
            topics: resultNodes.topics,
            compare: resultNodes.compare,
            sentiment: resultNodes.sentiment,
            keyword: resultNodes.keyword,
            chiSquare: resultNodes.chiSquare,
            plot: resultNodes.plot,
            ngram: resultNodes.ngram,
            cluster: resultNodes.cluster,
            kwic: resultNodes.kwic,
            collocate: resultNodes.collocate,
            locator: resultNodes.locator
        )
    }

    func syncResult(
        shell: WorkspaceShellSceneModel? = nil,
        activeTab: WorkspaceDetailTab,
        resultTab: WorkspaceDetailTab,
        word: WordSceneModel? = nil,
        tokenize: TokenizeSceneModel? = nil,
        stats: StatsSceneModel?,
        topics: TopicsSceneModel? = nil,
        compare: CompareSceneModel?,
        sentiment: SentimentSceneModel? = nil,
        keyword: KeywordSceneModel? = nil,
        chiSquare: ChiSquareSceneModel?,
        plot: PlotSceneModel? = nil,
        ngram: NgramSceneModel?,
        cluster: ClusterSceneModel? = nil,
        kwic: KWICSceneModel?,
        collocate: CollocateSceneModel?,
        locator: LocatorSceneModel?
    ) {
        let nodeBuilder = makeResultNodeBuilder(languageMode: WordZLocalization.shared.effectiveMode)

        switch resultTab {
        case .word:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                word: nodeBuilder.makeWordNode(from: word)
            )
        case .tokenize:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                tokenize: nodeBuilder.makeTokenizeNode(from: tokenize)
            )
        case .stats:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                stats: nodeBuilder.makeStatsNode(from: stats)
            )
        case .topics:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                topics: nodeBuilder.makeTopicsNode(from: topics)
            )
        case .compare:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                compare: nodeBuilder.makeCompareNode(from: compare)
            )
        case .sentiment:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                sentiment: nodeBuilder.makeSentimentNode(from: sentiment)
            )
        case .keyword:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                keyword: nodeBuilder.makeKeywordNode(from: keyword)
            )
        case .chiSquare:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                chiSquare: nodeBuilder.makeChiSquareNode(from: chiSquare)
            )
        case .plot:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                plot: nodeBuilder.makePlotNode(from: plot)
            )
        case .ngram:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                ngram: nodeBuilder.makeNgramNode(from: ngram)
            )
        case .cluster:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                cluster: nodeBuilder.makeClusterNode(from: cluster)
            )
        case .kwic:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                kwic: nodeBuilder.makeKWICNode(from: kwic)
            )
        case .collocate:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                collocate: nodeBuilder.makeCollocateNode(from: collocate)
            )
        case .locator:
            updateGraph(
                shell: shell,
                activeTab: activeTab,
                locator: nodeBuilder.makeLocatorNode(from: locator)
            )
        case .library, .settings:
            updateGraph(shell: shell, activeTab: activeTab)
        }
    }

    private func buildResultNodes(
        word: WordSceneModel? = nil,
        tokenize: TokenizeSceneModel? = nil,
        stats: StatsSceneModel?,
        topics: TopicsSceneModel? = nil,
        compare: CompareSceneModel?,
        sentiment: SentimentSceneModel? = nil,
        keyword: KeywordSceneModel? = nil,
        chiSquare: ChiSquareSceneModel?,
        plot: PlotSceneModel? = nil,
        ngram: NgramSceneModel?,
        cluster: ClusterSceneModel? = nil,
        kwic: KWICSceneModel?,
        collocate: CollocateSceneModel?,
        locator: LocatorSceneModel?
    ) -> WorkspaceSceneGraphResultNodes {
        let nodeBuilder = makeResultNodeBuilder(languageMode: WordZLocalization.shared.effectiveMode)
        return WorkspaceSceneGraphResultNodes(
            word: nodeBuilder.makeWordNode(from: word),
            tokenize: nodeBuilder.makeTokenizeNode(from: tokenize),
            stats: nodeBuilder.makeStatsNode(from: stats),
            topics: nodeBuilder.makeTopicsNode(from: topics),
            compare: nodeBuilder.makeCompareNode(from: compare),
            sentiment: nodeBuilder.makeSentimentNode(from: sentiment),
            keyword: nodeBuilder.makeKeywordNode(from: keyword),
            chiSquare: nodeBuilder.makeChiSquareNode(from: chiSquare),
            plot: nodeBuilder.makePlotNode(from: plot),
            ngram: nodeBuilder.makeNgramNode(from: ngram),
            cluster: nodeBuilder.makeClusterNode(from: cluster),
            kwic: nodeBuilder.makeKWICNode(from: kwic),
            collocate: nodeBuilder.makeCollocateNode(from: collocate),
            locator: nodeBuilder.makeLocatorNode(from: locator)
        )
    }
}

private struct WorkspaceSceneGraphResultNodes {
    let word: WorkspaceResultSceneNode?
    let tokenize: WorkspaceResultSceneNode?
    let stats: WorkspaceResultSceneNode?
    let topics: WorkspaceResultSceneNode?
    let compare: WorkspaceResultSceneNode?
    let sentiment: WorkspaceResultSceneNode?
    let keyword: WorkspaceResultSceneNode?
    let chiSquare: WorkspaceResultSceneNode?
    let plot: WorkspaceResultSceneNode?
    let ngram: WorkspaceResultSceneNode?
    let cluster: WorkspaceResultSceneNode?
    let kwic: WorkspaceResultSceneNode?
    let collocate: WorkspaceResultSceneNode?
    let locator: WorkspaceResultSceneNode?
}
