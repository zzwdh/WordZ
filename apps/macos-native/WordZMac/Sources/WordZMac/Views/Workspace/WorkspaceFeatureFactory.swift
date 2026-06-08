import SwiftUI

enum WorkspaceFeatureFactory {
    @MainActor
    static func makeDetailView(
        for route: WorkspaceMainRoute,
        workspace: MainWorkspaceViewModel,
        dispatcher: WorkspaceActionDispatcher
    ) -> AnyView {
        switch route {
        case .stats:
            return AnyView(
                StatsView(
                    viewModel: workspace.stats,
                    sidebar: workspace.sidebar,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.stats),
                    onAction: dispatcher.handleStatsAction
                )
            )
        case .word:
            return AnyView(
                WordView(
                    viewModel: workspace.word,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.word),
                    onAction: dispatcher.handleWordAction
                )
            )
        case .tokenize:
            return AnyView(
                TokenizeView(
                    viewModel: workspace.tokenize,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.tokenize),
                    onAction: dispatcher.handleTokenizeAction
                )
            )
        case .topics:
            return AnyView(
                TopicsView(
                    viewModel: workspace.topics,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.topics),
                    onAction: dispatcher.handleTopicsAction
                )
            )
        case .compare:
            return AnyView(
                CompareView(
                    viewModel: workspace.compare,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.compare),
                    onAction: dispatcher.handleCompareAction
                )
            )
        case .sentiment:
            return AnyView(
                SentimentView(
                    viewModel: workspace.sentiment,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.sentiment),
                    onAction: dispatcher.handleSentimentAction
                )
            )
        case .keyword:
            return AnyView(
                KeywordView(
                    viewModel: workspace.keyword,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.keyword),
                    onAction: dispatcher.handleKeywordAction
                )
            )
        case .chiSquare:
            return AnyView(
                ChiSquareView(
                    viewModel: workspace.chiSquare,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.chiSquare),
                    onAction: dispatcher.handleChiSquareAction
                )
            )
        case .plot:
            return AnyView(
                PlotView(
                    viewModel: workspace.plot,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.plot),
                    onAction: dispatcher.handlePlotAction
                )
            )
        case .ngram:
            return AnyView(
                NgramView(
                    viewModel: workspace.ngram,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.ngram),
                    onAction: dispatcher.handleNgramAction
                )
            )
        case .cluster:
            return AnyView(
                ClusterView(
                    viewModel: workspace.cluster,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.cluster),
                    onAction: dispatcher.handleClusterAction
                )
            )
        case .kwic:
            return AnyView(
                KWICView(
                    viewModel: workspace.kwic,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.kwic),
                    onAction: dispatcher.handleKWICAction
                )
            )
        case .collocate:
            return AnyView(
                CollocateView(
                    viewModel: workspace.collocate,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.collocate),
                    onAction: dispatcher.handleCollocateAction
                )
            )
        case .locator:
            return AnyView(
                LocatorView(
                    viewModel: workspace.locator,
                    isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.locator),
                    onAction: dispatcher.handleLocatorAction
                )
            )
        }
    }
}
