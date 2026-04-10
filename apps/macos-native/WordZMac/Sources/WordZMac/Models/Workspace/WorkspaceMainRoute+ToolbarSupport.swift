import Foundation

extension WorkspaceMainRoute {
    var toolbarRunAction: WorkspaceToolbarAction? {
        switch self {
        case .stats:
            return .runStats
        case .word:
            return .runWord
        case .tokenize:
            return .runTokenize
        case .topics:
            return .runTopics
        case .compare:
            return .runCompare
        case .keyword:
            return .runKeyword
        case .chiSquare:
            return .runChiSquare
        case .ngram:
            return .runNgram
        case .kwic:
            return .runKWIC
        case .collocate:
            return .runCollocate
        case .locator:
            return .runLocator
        }
    }
}
