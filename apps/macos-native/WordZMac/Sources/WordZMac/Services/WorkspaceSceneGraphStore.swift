import Foundation

@MainActor
final class WorkspaceSceneGraphStore: ObservableObject {
    @Published private(set) var graph = WorkspaceSceneGraph.empty

    private var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }

    func sync(
        context: WorkspaceSceneContext,
        sidebar: WorkspaceSidebarSceneModel,
        shell: WorkspaceShellSceneModel,
        library: LibraryManagementSceneModel,
        settings: SettingsPaneSceneModel,
        activeTab: WorkspaceDetailTab,
        word: WordSceneModel? = nil,
        tokenize: TokenizeSceneModel? = nil,
        wordCloud: WordCloudSceneModel?,
        stats: StatsSceneModel?,
        topics: TopicsSceneModel? = nil,
        compare: CompareSceneModel?,
        chiSquare: ChiSquareSceneModel?,
        ngram: NgramSceneModel?,
        kwic: KWICSceneModel?,
        collocate: CollocateSceneModel?,
        locator: LocatorSceneModel?
    ) {
        updateGraph(
            context: context,
            sidebar: sidebar,
            shell: shell,
            library: library,
            settings: settings,
            activeTab: activeTab,
            word: makeWordNode(from: word),
            tokenize: makeTokenizeNode(from: tokenize),
            wordCloud: makeWordCloudNode(from: wordCloud),
            stats: makeStatsNode(from: stats),
            topics: makeTopicsNode(from: topics),
            compare: makeCompareNode(from: compare),
            chiSquare: makeChiSquareNode(from: chiSquare),
            ngram: makeNgramNode(from: ngram),
            kwic: makeKWICNode(from: kwic),
            collocate: makeCollocateNode(from: collocate),
            locator: makeLocatorNode(from: locator)
        )
    }

    func syncShellNavigation(shell: WorkspaceShellSceneModel, activeTab: WorkspaceDetailTab) {
        updateGraph(shell: shell, activeTab: activeTab)
    }

    func syncSidebarAndLibrary(
        sidebar: WorkspaceSidebarSceneModel,
        library: LibraryManagementSceneModel,
        shell: WorkspaceShellSceneModel? = nil,
        activeTab: WorkspaceDetailTab? = nil
    ) {
        updateGraph(
            sidebar: sidebar,
            shell: shell,
            library: library,
            activeTab: activeTab
        )
    }

    func syncSettings(_ settings: SettingsPaneSceneModel) {
        updateGraph(settings: settings)
    }

    func syncResults(
        shell: WorkspaceShellSceneModel? = nil,
        activeTab: WorkspaceDetailTab,
        word: WordSceneModel? = nil,
        tokenize: TokenizeSceneModel? = nil,
        wordCloud: WordCloudSceneModel?,
        stats: StatsSceneModel?,
        topics: TopicsSceneModel? = nil,
        compare: CompareSceneModel?,
        chiSquare: ChiSquareSceneModel?,
        ngram: NgramSceneModel?,
        kwic: KWICSceneModel?,
        collocate: CollocateSceneModel?,
        locator: LocatorSceneModel?
    ) {
        updateGraph(
            shell: shell,
            activeTab: activeTab,
            word: makeWordNode(from: word),
            tokenize: makeTokenizeNode(from: tokenize),
            wordCloud: makeWordCloudNode(from: wordCloud),
            stats: makeStatsNode(from: stats),
            topics: makeTopicsNode(from: topics),
            compare: makeCompareNode(from: compare),
            chiSquare: makeChiSquareNode(from: chiSquare),
            ngram: makeNgramNode(from: ngram),
            kwic: makeKWICNode(from: kwic),
            collocate: makeCollocateNode(from: collocate),
            locator: makeLocatorNode(from: locator)
        )
    }

    private func updateGraph(
        context: WorkspaceSceneContext? = nil,
        sidebar: WorkspaceSidebarSceneModel? = nil,
        shell: WorkspaceShellSceneModel? = nil,
        library: LibraryManagementSceneModel? = nil,
        settings: SettingsPaneSceneModel? = nil,
        activeTab: WorkspaceDetailTab? = nil,
        word: WorkspaceResultSceneNode? = nil,
        tokenize: WorkspaceResultSceneNode? = nil,
        wordCloud: WorkspaceResultSceneNode? = nil,
        stats: WorkspaceResultSceneNode? = nil,
        topics: WorkspaceResultSceneNode? = nil,
        compare: WorkspaceResultSceneNode? = nil,
        chiSquare: WorkspaceResultSceneNode? = nil,
        ngram: WorkspaceResultSceneNode? = nil,
        kwic: WorkspaceResultSceneNode? = nil,
        collocate: WorkspaceResultSceneNode? = nil,
        locator: WorkspaceResultSceneNode? = nil
    ) {
        graph = WorkspaceSceneGraph(
            context: context ?? graph.context,
            sidebar: sidebar ?? graph.sidebar,
            shell: shell ?? graph.shell,
            library: library ?? graph.library,
            settings: settings ?? graph.settings,
            activeTab: activeTab ?? graph.activeTab,
            word: word ?? graph.word,
            tokenize: tokenize ?? graph.tokenize,
            wordCloud: wordCloud ?? graph.wordCloud,
            stats: stats ?? graph.stats,
            topics: topics ?? graph.topics,
            compare: compare ?? graph.compare,
            chiSquare: chiSquare ?? graph.chiSquare,
            ngram: ngram ?? graph.ngram,
            kwic: kwic ?? graph.kwic,
            collocate: collocate ?? graph.collocate,
            locator: locator ?? graph.locator
        )
    }

    private func makeWordNode(from scene: WordSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.word.displayTitle(in: languageMode),
                status: wordZText("尚未生成词表结果", "No Word results yet", mode: languageMode)
            )
        }
        let status: String
        if scene.query.isEmpty {
            status = wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.filteredRows)"
        } else {
            status = wordZText("过滤", "Filter", mode: languageMode) + " \(scene.query) · " + wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.filteredRows)"
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.word.displayTitle(in: languageMode),
            status: status,
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }

    private func makeStatsNode(from scene: StatsSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.stats.displayTitle(in: languageMode),
                status: wordZText("尚未生成统计结果", "No stats results yet", mode: languageMode)
            )
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.stats.displayTitle(in: languageMode),
            status: wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.totalRows)",
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }

    private func makeTokenizeNode(from scene: TokenizeSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.tokenize.displayTitle(in: languageMode),
                status: wordZText("尚未生成分词结果", "No tokenization results yet", mode: languageMode)
            )
        }
        let status: String
        if scene.query.isEmpty {
            status = wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleTokens) / \(scene.filteredTokens)"
        } else {
            status = wordZText("过滤", "Filter", mode: languageMode) + " \(scene.query) · "
                + wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleTokens) / \(scene.filteredTokens)"
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.tokenize.displayTitle(in: languageMode),
            status: status,
            totalRows: scene.totalTokens,
            visibleRows: scene.visibleTokens,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    private func makeTopicsNode(from scene: TopicsSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.topics.displayTitle(in: languageMode),
                status: wordZText("尚未生成 Topics 结果", "No Topics results yet", mode: languageMode)
            )
        }
        let clusterStatus = "\(wordZText("主题", "Topics", mode: languageMode)) \(scene.visibleClusters) / \(scene.totalClusters)"
        let segmentStatus = "\(wordZText("片段", "Segments", mode: languageMode)) \(scene.visibleSegments) / \(scene.totalSegments)"
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.topics.displayTitle(in: languageMode),
            status: "\(clusterStatus) · \(segmentStatus)",
            totalRows: scene.totalSegments,
            visibleRows: scene.visibleSegments,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    private func makeWordCloudNode(from scene: WordCloudSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.wordCloud.displayTitle(in: languageMode),
                status: wordZText("尚未生成词云结果", "No word cloud results yet", mode: languageMode)
            )
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.wordCloud.displayTitle(in: languageMode),
            status: wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.filteredRows) · Top \(scene.limit)",
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    private func makeKWICNode(from scene: KWICSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.kwic.displayTitle(in: languageMode),
                status: wordZText("尚未生成 KWIC 结果", "No KWIC results yet", mode: languageMode)
            )
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.kwic.displayTitle(in: languageMode),
            status: wordZText("关键词", "Keyword", mode: languageMode) + " \(scene.query) · " + wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.totalRows)",
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    private func makeCompareNode(from scene: CompareSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.compare.displayTitle(in: languageMode),
                status: wordZText("尚未生成对比结果", "No compare results yet", mode: languageMode)
            )
        }
        let status: String
        if scene.query.isEmpty {
            status = wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.filteredRows)"
        } else {
            status = wordZText("过滤", "Filter", mode: languageMode) + " \(scene.query) · " + wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.filteredRows)"
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.compare.displayTitle(in: languageMode),
            status: status,
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    private func makeChiSquareNode(from scene: ChiSquareSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.chiSquare.displayTitle(in: languageMode),
                status: wordZText("尚未生成卡方结果", "No chi-square results yet", mode: languageMode)
            )
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.chiSquare.displayTitle(in: languageMode),
            status: scene.summary,
            totalRows: scene.tableRows.count,
            visibleRows: scene.tableRows.count,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    private func makeNgramNode(from scene: NgramSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.ngram.displayTitle(in: languageMode),
                status: wordZText("尚未生成 N-Gram 结果", "No N-Gram results yet", mode: languageMode)
            )
        }
        let status: String
        if scene.query.isEmpty {
            status = "\(scene.n)-gram · " + wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.filteredRows)"
        } else {
            status = "\(scene.n)-gram · " + wordZText("过滤", "Filter", mode: languageMode) + " \(scene.query) · " + wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.filteredRows)"
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.ngram.displayTitle(in: languageMode),
            status: status,
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    private func makeCollocateNode(from scene: CollocateSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.collocate.displayTitle(in: languageMode),
                status: wordZText("尚未生成搭配词结果", "No collocate results yet", mode: languageMode)
            )
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.collocate.displayTitle(in: languageMode),
            status: wordZText("节点词", "Node", mode: languageMode) + " \(scene.query) · " + wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.totalRows)",
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    private func makeLocatorNode(from scene: LocatorSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return .empty(
                title: WorkspaceDetailTab.locator.displayTitle(in: languageMode),
                status: wordZText("尚未生成定位结果", "No locator results yet", mode: languageMode)
            )
        }
        return WorkspaceResultSceneNode(
            title: WorkspaceDetailTab.locator.displayTitle(in: languageMode),
            status: wordZText("句", "Sentence", mode: languageMode) + " \(scene.source.sentenceId + 1) · " + wordZText("显示", "Showing", mode: languageMode) + " \(scene.visibleRows) / \(scene.totalRows)",
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            hasResult: true,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }
}
