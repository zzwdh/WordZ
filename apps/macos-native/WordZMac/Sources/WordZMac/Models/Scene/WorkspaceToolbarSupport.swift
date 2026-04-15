import Foundation

extension WorkspaceToolbarSceneModel {
    func item(for action: WorkspaceToolbarAction) -> WorkspaceToolbarActionItem? {
        items.first(where: { $0.action == action })
    }
}

extension WorkspaceToolbarAction {
    var nativeCommand: NativeAppCommand {
        switch self {
        case .refresh:
            return .refreshWorkspace
        case .showLibrary:
            return .showLibrary
        case .openSelected:
            return .openSelectedCorpus
        case .openSourceReader:
            return .openSourceReader
        case .previewCurrentCorpus:
            return .quickLookCurrentCorpus
        case .shareCurrentContent:
            return .shareCurrentContent
        case .runStats:
            return .runStats
        case .runWord:
            return .runWord
        case .runTokenize:
            return .runTokenize
        case .runTopics:
            return .runTopics
        case .runCompare:
            return .runCompare
        case .runSentiment:
            return .runSentiment
        case .runKeyword:
            return .runKeyword
        case .runChiSquare:
            return .runChiSquare
        case .runPlot:
            return .runPlot
        case .runNgram:
            return .runNgram
        case .runCluster:
            return .runCluster
        case .runKWIC:
            return .runKWIC
        case .runCollocate:
            return .runCollocate
        case .runLocator:
            return .runLocator
        case .exportCurrent:
            return .exportCurrent
        }
    }

    var toolbarSymbolName: String {
        switch self {
        case .refresh:
            return "arrow.clockwise"
        case .showLibrary:
            return "books.vertical"
        case .openSelected:
            return "arrow.up.right.square"
        case .openSourceReader:
            return "doc.text.magnifyingglass"
        case .previewCurrentCorpus:
            return "space"
        case .shareCurrentContent:
            return "square.and.arrow.up"
        case .runStats, .runWord, .runTokenize, .runTopics, .runCompare, .runSentiment, .runKeyword, .runChiSquare, .runPlot, .runNgram, .runCluster, .runKWIC, .runCollocate, .runLocator:
            return "play.fill"
        case .exportCurrent:
            return "square.and.arrow.up"
        }
    }
}
