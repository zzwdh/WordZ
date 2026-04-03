import Foundation

enum SidebarAction: Equatable, Identifiable {
    case refresh
    case openSelected
    case quickLookSelected(String)

    var id: String {
        switch self {
        case .refresh:
            return "refresh"
        case .openSelected:
            return "openSelected"
        case .quickLookSelected(let corpusID):
            return "quickLookSelected:\(corpusID)"
        }
    }
}
