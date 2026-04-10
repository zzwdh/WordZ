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
        case .runKeyword:
            return .runKeyword
        case .runChiSquare:
            return .runChiSquare
        case .runNgram:
            return .runNgram
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
}
