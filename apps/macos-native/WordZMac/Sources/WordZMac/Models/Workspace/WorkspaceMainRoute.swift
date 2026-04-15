import Foundation

enum WorkspaceMainRoute: String, CaseIterable, Identifiable, Hashable {
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

    var id: String { rawValue }

    static var allCases: [WorkspaceMainRoute] {
        WorkspaceFeatureRegistry.mainRoutes
    }

    init(tab: WorkspaceDetailTab) {
        self = WorkspaceFeatureRegistry.descriptor(for: tab.mainWorkspaceTab).route
    }

    var tab: WorkspaceDetailTab {
        WorkspaceFeatureRegistry.descriptor(for: self).tab
    }

    func displayTitle(in mode: AppLanguageMode) -> String {
        WorkspaceFeatureRegistry.descriptor(for: self).title(in: mode)
    }

    var symbolName: String {
        WorkspaceFeatureRegistry.descriptor(for: self).symbolName
    }
}
