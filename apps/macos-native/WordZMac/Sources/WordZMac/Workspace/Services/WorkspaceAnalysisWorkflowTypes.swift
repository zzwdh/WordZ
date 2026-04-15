import Foundation

enum ConcordanceSavedSetScope: Equatable {
    case current
    case visible
}

enum KeywordKWICScope {
    case focus
    case reference
}

enum KeywordSavedListExportScope {
    case selected
    case all
}

enum CompareDrilldownTarget {
    case kwic
    case collocate
}
