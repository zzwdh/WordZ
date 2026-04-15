import Foundation

enum WorkspaceDetailTab: String, CaseIterable, Identifiable {
    case library = "Library"
    case stats = "Stats"
    case word = "Word"
    case tokenize = "Tokenize"
    case topics = "Topics"
    case compare = "Compare"
    case sentiment = "Sentiment"
    case keyword = "Keyword"
    case chiSquare = "Chi-Square"
    case plot = "Plot"
    case ngram = "N-Gram"
    case cluster = "Cluster"
    case kwic = "KWIC"
    case collocate = "Collocate"
    case locator = "Locator"
    case settings = "Settings"

    var id: String { rawValue }

    static var mainWorkspaceTabs: [WorkspaceDetailTab] {
        WorkspaceFeatureRegistry.mainTabs
    }

    var mainWorkspaceTab: WorkspaceDetailTab {
        switch self {
        case .library, .settings:
            return .stats
        default:
            return self
        }
    }

    func displayTitle(in mode: AppLanguageMode) -> String {
        if case .library = self {
            return wordZText("语料库", "Library", mode: mode)
        }
        if case .settings = self {
            return wordZText("设置", "Settings", mode: mode)
        }
        if WorkspaceFeatureRegistry.mainTabs.contains(self) {
            return WorkspaceFeatureRegistry.descriptor(for: self).title(in: mode)
        }

        switch self {
        case .stats, .word, .tokenize, .topics, .compare, .sentiment, .keyword, .chiSquare, .plot, .cluster, .collocate, .locator:
            return WorkspaceFeatureRegistry.descriptor(for: self).title(in: mode)
        case .ngram:
            return "N-Gram"
        case .kwic:
            return "KWIC"
        case .library, .settings:
            return rawValue
        }
    }

    var displayTitle: String {
        displayTitle(in: .system)
    }

    var snapshotValue: String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func fromSnapshotValue(_ value: String) -> WorkspaceDetailTab? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "library":
            return .library
        case "stats":
            return .stats
        case "word":
            return .word
        case "tokenize", "token":
            return .tokenize
        case "topics", "topic":
            return .topics
        case "compare":
            return .compare
        case "sentiment":
            return .sentiment
        case "keyword", "keywords":
            return .keyword
        case "chi-square", "chisquare", "chi_square":
            return .chiSquare
        case "plot":
            return .plot
        case "ngram":
            return .ngram
        case "cluster":
            return .cluster
        case "word-cloud", "wordcloud", "word_cloud", "word cloud":
            return .word
        case "kwic":
            return .kwic
        case "collocate":
            return .collocate
        case "locator":
            return .locator
        case "settings":
            return .settings
        default:
            return nil
        }
    }

    var symbolName: String {
        if case .library = self {
            return "books.vertical"
        }
        if case .settings = self {
            return "gearshape"
        }
        if WorkspaceFeatureRegistry.mainTabs.contains(self) {
            return WorkspaceFeatureRegistry.descriptor(for: self).symbolName
        }

        switch self {
        case .stats, .word, .tokenize, .topics, .compare, .sentiment, .keyword, .chiSquare, .plot, .cluster, .collocate, .locator:
            return WorkspaceFeatureRegistry.descriptor(for: self).symbolName
        case .ngram:
            return "text.line.first.and.arrowtriangle.forward"
        case .kwic:
            return "quote.opening"
        case .library, .settings:
            return rawValue
        }
    }
}
