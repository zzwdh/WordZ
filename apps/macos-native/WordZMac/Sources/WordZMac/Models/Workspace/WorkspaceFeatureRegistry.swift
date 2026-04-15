import Foundation
import SwiftUI

typealias WorkspaceFeatureDetailViewBuilder =
    @MainActor (_ workspace: MainWorkspaceViewModel, _ dispatcher: WorkspaceActionDispatcher) -> AnyView

enum WorkspaceFeatureKey: String, CaseIterable, Identifiable {
    case stats
    case word
    case tokenize
    case topics
    case compare
    case sentiment
    case keyword
    case chiSquare
    case plot
    case ngram
    case cluster
    case kwic
    case collocate
    case locator

    var id: String { rawValue }
}

struct WorkspaceFeatureDescriptor: Identifiable, Equatable {
    let key: WorkspaceFeatureKey
    let route: WorkspaceMainRoute
    let tab: WorkspaceDetailTab
    let titleZh: String
    let titleEn: String
    let sidebarSubtitleZh: String
    let sidebarSubtitleEn: String
    let symbolName: String
    let commandAction: WorkspaceToolbarAction?
    let showsInSidebar: Bool
    let showsInPagePicker: Bool
    let showsInCommands: Bool
    let detailViewBuilder: WorkspaceFeatureDetailViewBuilder

    var id: WorkspaceFeatureKey { key }

    func title(in mode: AppLanguageMode) -> String {
        wordZText(titleZh, titleEn, mode: mode)
    }

    func sidebarSubtitle(in mode: AppLanguageMode) -> String {
        wordZText(sidebarSubtitleZh, sidebarSubtitleEn, mode: mode)
    }

    @MainActor
    func makeDetailView(
        workspace: MainWorkspaceViewModel,
        dispatcher: WorkspaceActionDispatcher
    ) -> AnyView {
        detailViewBuilder(workspace, dispatcher)
    }

    static func == (lhs: WorkspaceFeatureDescriptor, rhs: WorkspaceFeatureDescriptor) -> Bool {
        lhs.key == rhs.key &&
            lhs.route == rhs.route &&
            lhs.tab == rhs.tab &&
            lhs.titleZh == rhs.titleZh &&
            lhs.titleEn == rhs.titleEn &&
            lhs.sidebarSubtitleZh == rhs.sidebarSubtitleZh &&
            lhs.sidebarSubtitleEn == rhs.sidebarSubtitleEn &&
            lhs.symbolName == rhs.symbolName &&
            lhs.commandAction == rhs.commandAction &&
            lhs.showsInSidebar == rhs.showsInSidebar &&
            lhs.showsInPagePicker == rhs.showsInPagePicker &&
            lhs.showsInCommands == rhs.showsInCommands
    }
}

enum WorkspaceFeatureRegistry {
    static let descriptors: [WorkspaceFeatureDescriptor] = [
        .init(
            key: .stats,
            route: .stats,
            tab: .stats,
            titleZh: "统计",
            titleEn: "Stats",
            sidebarSubtitleZh: "查看语料规模、类型数与总体分布",
            sidebarSubtitleEn: "Inspect corpus size, type count, and distribution",
            symbolName: "chart.bar",
            commandAction: .runStats,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    StatsView(
                        viewModel: workspace.stats,
                        sidebar: workspace.sidebar,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleStatsAction
                    )
                )
            }
        ),
        .init(
            key: .word,
            route: .word,
            tab: .word,
            titleZh: "词表",
            titleEn: "Word",
            sidebarSubtitleZh: "查看词表、频次与标准化频率",
            sidebarSubtitleEn: "Inspect word lists, counts, and normalized frequency",
            symbolName: "textformat.abc",
            commandAction: .runWord,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    WordView(
                        viewModel: workspace.word,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleWordAction
                    )
                )
            }
        ),
        .init(
            key: .tokenize,
            route: .tokenize,
            tab: .tokenize,
            titleZh: "分词",
            titleEn: "Tokenize",
            sidebarSubtitleZh: "生成分词结果并导出清洗后的文本",
            sidebarSubtitleEn: "Generate tokenized output and cleaned text",
            symbolName: "text.word.spacing",
            commandAction: .runTokenize,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    TokenizeView(
                        viewModel: workspace.tokenize,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleTokenizeAction
                    )
                )
            }
        ),
        .init(
            key: .topics,
            route: .topics,
            tab: .topics,
            titleZh: "主题",
            titleEn: "Topics",
            sidebarSubtitleZh: "查看主题簇、代表词与片段分布",
            sidebarSubtitleEn: "Inspect topic clusters, keywords, and segment spread",
            symbolName: "square.grid.3x3.topleft.filled",
            commandAction: .runTopics,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    TopicsView(
                        viewModel: workspace.topics,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleTopicsAction
                    )
                )
            }
        ),
        .init(
            key: .compare,
            route: .compare,
            tab: .compare,
            titleZh: "对比",
            titleEn: "Compare",
            sidebarSubtitleZh: "对比语料之间的显著差异与排序",
            sidebarSubtitleEn: "Compare corpora and inspect ranked differences",
            symbolName: "arrow.left.and.right.square",
            commandAction: .runCompare,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    CompareView(
                        viewModel: workspace.compare,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleCompareAction
                    )
                )
            }
        ),
        .init(
            key: .sentiment,
            route: .sentiment,
            tab: .sentiment,
            titleZh: "情感",
            titleEn: "Sentiment",
            sidebarSubtitleZh: "查看 neutrality / positivity / negativity 的启发式分布",
            sidebarSubtitleEn: "Inspect heuristic neutrality / positivity / negativity distributions",
            symbolName: "waveform.path.ecg.text",
            commandAction: .runSentiment,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    SentimentView(
                        viewModel: workspace.sentiment,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleSentimentAction
                    )
                )
            }
        ),
        .init(
            key: .keyword,
            route: .keyword,
            tab: .keyword,
            titleZh: "关键词",
            titleEn: "Keyword",
            sidebarSubtitleZh: "查看目标语料相对参照语料的关键词",
            sidebarSubtitleEn: "Inspect keywords against the reference corpus",
            symbolName: "key",
            commandAction: .runKeyword,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    KeywordView(
                        viewModel: workspace.keyword,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleKeywordAction
                    )
                )
            }
        ),
        .init(
            key: .chiSquare,
            route: .chiSquare,
            tab: .chiSquare,
            titleZh: "卡方",
            titleEn: "Chi-Square",
            sidebarSubtitleZh: "运行列联表与卡方显著性检验",
            sidebarSubtitleEn: "Run contingency tables and chi-square significance checks",
            symbolName: "function",
            commandAction: .runChiSquare,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    ChiSquareView(
                        viewModel: workspace.chiSquare,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleChiSquareAction
                    )
                )
            }
        ),
        .init(
            key: .plot,
            route: .plot,
            tab: .plot,
            titleZh: "图表",
            titleEn: "Plot",
            sidebarSubtitleZh: "把现有分析结果转成图表与导出表",
            sidebarSubtitleEn: "Turn current analysis results into charts and exportable tables",
            symbolName: "chart.xyaxis.line",
            commandAction: .runPlot,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    PlotView(
                        viewModel: workspace.plot,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handlePlotAction
                    )
                )
            }
        ),
        .init(
            key: .ngram,
            route: .ngram,
            tab: .ngram,
            titleZh: "N-Gram",
            titleEn: "N-Gram",
            sidebarSubtitleZh: "查看连续词串及其频率表现",
            sidebarSubtitleEn: "Inspect phrase sequences and their frequency",
            symbolName: "text.line.first.and.arrowtriangle.forward",
            commandAction: .runNgram,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    NgramView(
                        viewModel: workspace.ngram,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleNgramAction
                    )
                )
            }
        ),
        .init(
            key: .cluster,
            route: .cluster,
            tab: .cluster,
            titleZh: "词串簇",
            titleEn: "Cluster",
            sidebarSubtitleZh: "查看连续高频词串并下钻到 KWIC",
            sidebarSubtitleEn: "Inspect lexical bundles and drill down into KWIC",
            symbolName: "square.stack.3d.up",
            commandAction: .runCluster,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    ClusterView(
                        viewModel: workspace.cluster,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleClusterAction
                    )
                )
            }
        ),
        .init(
            key: .kwic,
            route: .kwic,
            tab: .kwic,
            titleZh: "KWIC",
            titleEn: "KWIC",
            sidebarSubtitleZh: "查看关键词在上下文中的索引行",
            sidebarSubtitleEn: "View concordance lines around a keyword",
            symbolName: "quote.opening",
            commandAction: .runKWIC,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    KWICView(
                        viewModel: workspace.kwic,
                        evidenceWorkbench: workspace.evidenceWorkbench,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleKWICAction
                    )
                )
            }
        ),
        .init(
            key: .collocate,
            route: .collocate,
            tab: .collocate,
            titleZh: "搭配词",
            titleEn: "Collocate",
            sidebarSubtitleZh: "查看节点词的共现词与关联强度",
            sidebarSubtitleEn: "Inspect co-occurring words and association scores",
            symbolName: "link",
            commandAction: .runCollocate,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    CollocateView(
                        viewModel: workspace.collocate,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleCollocateAction
                    )
                )
            }
        ),
        .init(
            key: .locator,
            route: .locator,
            tab: .locator,
            titleZh: "定位",
            titleEn: "Locator",
            sidebarSubtitleZh: "从 KWIC 结果继续追踪原始上下文",
            sidebarSubtitleEn: "Follow source context from KWIC results",
            symbolName: "scope",
            commandAction: .runLocator,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    LocatorView(
                        viewModel: workspace.locator,
                        evidenceWorkbench: workspace.evidenceWorkbench,
                        isBusy: workspace.shell.isBusy,
                        onAction: dispatcher.handleLocatorAction
                    )
                )
            }
        )
    ]

    static let descriptorsByRoute = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.route, $0) })
    static let descriptorsByTab = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.tab, $0) })

    static var mainRoutes: [WorkspaceMainRoute] {
        descriptors.filter(\.showsInPagePicker).map(\.route)
    }

    static var mainTabs: [WorkspaceDetailTab] {
        descriptors.filter(\.showsInSidebar).map(\.tab)
    }

    static var commandDescriptors: [WorkspaceFeatureDescriptor] {
        descriptors.filter(\.showsInCommands)
    }

    static func descriptor(for route: WorkspaceMainRoute) -> WorkspaceFeatureDescriptor {
        descriptorsByRoute[route] ?? descriptors[0]
    }

    static func descriptor(for tab: WorkspaceDetailTab) -> WorkspaceFeatureDescriptor {
        descriptorsByTab[tab] ?? descriptors[0]
    }
}
