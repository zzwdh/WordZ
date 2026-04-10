import Foundation

enum WorkspaceDetailTab: String, CaseIterable, Identifiable {
    case library = "Library"
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
    case settings = "Settings"

    var id: String { rawValue }

    static var mainWorkspaceTabs: [WorkspaceDetailTab] {
        allCases.filter { $0 != .library && $0 != .settings }
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
        switch self {
        case .library:
            return wordZText("语料库", "Library", mode: mode)
        case .stats:
            return wordZText("统计", "Stats", mode: mode)
        case .word:
            return wordZText("词表", "Word", mode: mode)
        case .tokenize:
            return wordZText("分词", "Tokenize", mode: mode)
        case .topics:
            return wordZText("主题", "Topics", mode: mode)
        case .compare:
            return wordZText("对比", "Compare", mode: mode)
        case .keyword:
            return wordZText("关键词", "Keyword", mode: mode)
        case .chiSquare:
            return wordZText("卡方", "Chi-Square", mode: mode)
        case .ngram:
            return "N-Gram"
        case .kwic:
            return "KWIC"
        case .collocate:
            return wordZText("搭配词", "Collocate", mode: mode)
        case .locator:
            return wordZText("定位", "Locator", mode: mode)
        case .settings:
            return wordZText("设置", "Settings", mode: mode)
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
        case "keyword", "keywords":
            return .keyword
        case "chi-square", "chisquare", "chi_square":
            return .chiSquare
        case "ngram":
            return .ngram
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
        switch self {
        case .library:
            return "books.vertical"
        case .stats:
            return "chart.bar"
        case .word:
            return "textformat.abc"
        case .tokenize:
            return "text.word.spacing"
        case .topics:
            return "square.grid.3x3.topleft.filled"
        case .compare:
            return "arrow.left.and.right.square"
        case .keyword:
            return "key"
        case .chiSquare:
            return "function"
        case .ngram:
            return "text.line.first.and.arrowtriangle.forward"
        case .kwic:
            return "quote.opening"
        case .collocate:
            return "link"
        case .locator:
            return "scope"
        case .settings:
            return "gearshape"
        }
    }
}
