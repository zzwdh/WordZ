import Foundation

enum SidebarAction: Equatable, Identifiable {
    case refresh
    case openSelected
    case applyCorpusSet(String?)
    case selectTargetCorpus(String)
    case selectReferenceCorpus(String?)
    case openAnalysis(WorkspaceDetailTab)
    case exportCurrent
    case quickLookSelected(String)
    case showCorpusInfoSelected(String)

    var id: String {
        switch self {
        case .refresh:
            return "refresh"
        case .openSelected:
            return "openSelected"
        case .applyCorpusSet(let corpusSetID):
            return "applyCorpusSet:\(corpusSetID ?? "none")"
        case .selectTargetCorpus(let corpusID):
            return "selectTargetCorpus:\(corpusID)"
        case .selectReferenceCorpus(let corpusID):
            return "selectReferenceCorpus:\(corpusID ?? "none")"
        case .openAnalysis(let tab):
            return "openAnalysis:\(tab.rawValue)"
        case .exportCurrent:
            return "exportCurrent"
        case .quickLookSelected(let corpusID):
            return "quickLookSelected:\(corpusID)"
        case .showCorpusInfoSelected(let corpusID):
            return "showCorpusInfoSelected:\(corpusID)"
        }
    }
}
