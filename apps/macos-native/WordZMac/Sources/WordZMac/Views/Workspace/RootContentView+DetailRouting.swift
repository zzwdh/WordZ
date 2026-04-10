import SwiftUI

extension RootContentView {
    @ViewBuilder
    var currentDetailView: some View {
        switch viewModel.selectedRoute {
        case .stats:
            StatsView(
                viewModel: viewModel.stats,
                sidebar: viewModel.sidebar,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleStatsAction
            )
        case .word:
            WordView(
                viewModel: viewModel.word,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleWordAction
            )
        case .tokenize:
            TokenizeView(
                viewModel: viewModel.tokenize,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleTokenizeAction
            )
        case .topics:
            TopicsView(
                viewModel: viewModel.topics,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleTopicsAction
            )
        case .compare:
            CompareView(
                viewModel: viewModel.compare,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleCompareAction
            )
        case .keyword:
            KeywordView(
                viewModel: viewModel.keyword,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleKeywordAction
            )
        case .chiSquare:
            ChiSquareView(
                viewModel: viewModel.chiSquare,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleChiSquareAction
            )
        case .ngram:
            NgramView(
                viewModel: viewModel.ngram,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleNgramAction
            )
        case .kwic:
            KWICView(
                viewModel: viewModel.kwic,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleKWICAction
            )
        case .collocate:
            CollocateView(
                viewModel: viewModel.collocate,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleCollocateAction
            )
        case .locator:
            LocatorView(
                viewModel: viewModel.locator,
                isBusy: viewModel.shell.isBusy,
                onAction: dispatcher.handleLocatorAction
            )
        }
    }
}
