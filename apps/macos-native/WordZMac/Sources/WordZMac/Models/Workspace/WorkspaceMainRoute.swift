import Foundation

enum WorkspaceMainRoute: String, CaseIterable, Identifiable, Hashable {
    case stats = "Stats"
    case word = "Word"
    case tokenize = "Tokenize"
    case topics = "Topics"
    case compare = "Compare"
    case keyword = "Keyword"
    case chiSquare = "Chi-Square"
    case ngram = "N-Gram"
    case kwic = "KWIC"
    case collocate = "Collocate"
    case locator = "Locator"

    var id: String { rawValue }

    init(tab: WorkspaceDetailTab) {
        switch tab.mainWorkspaceTab {
        case .stats:
            self = .stats
        case .word:
            self = .word
        case .tokenize:
            self = .tokenize
        case .topics:
            self = .topics
        case .compare:
            self = .compare
        case .keyword:
            self = .keyword
        case .chiSquare:
            self = .chiSquare
        case .ngram:
            self = .ngram
        case .kwic:
            self = .kwic
        case .collocate:
            self = .collocate
        case .locator:
            self = .locator
        case .library, .settings:
            self = .stats
        }
    }

    var tab: WorkspaceDetailTab {
        switch self {
        case .stats:
            return .stats
        case .word:
            return .word
        case .tokenize:
            return .tokenize
        case .topics:
            return .topics
        case .compare:
            return .compare
        case .keyword:
            return .keyword
        case .chiSquare:
            return .chiSquare
        case .ngram:
            return .ngram
        case .kwic:
            return .kwic
        case .collocate:
            return .collocate
        case .locator:
            return .locator
        }
    }

    func displayTitle(in mode: AppLanguageMode) -> String {
        tab.displayTitle(in: mode)
    }

    var symbolName: String {
        tab.symbolName
    }
}
