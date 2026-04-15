import Foundation

enum KeywordPageAction {
    case run
    case changeTargetCorpus(String)
    case changeReferenceCorpus(String)
    case changeStatistic(KeywordStatisticMethod)
    case changeTab(KeywordSuiteTab)
    case changeSort(KeywordSortMode)
    case sortByColumn(KeywordColumnKey)
    case changePageSize(KeywordPageSize)
    case toggleColumn(KeywordColumnKey)
    case selectRow(String?)
    case saveCurrentList
    case refreshSavedLists
    case deleteSavedList(String)
    case importSavedListsJSON
    case exportSelectedSavedListJSON
    case exportAllSavedListsJSON
    case importReferenceWordList
    case exportRowContext
    case openFocusKWIC
    case openReferenceKWIC
    case openCompareDistribution
    case previousPage
    case nextPage
}

extension KeywordPageAction {
    var routesThroughViewModel: Bool {
        switch self {
        case .changeTargetCorpus,
             .changeReferenceCorpus,
             .changeStatistic,
             .changeTab,
             .changeSort,
             .sortByColumn,
             .changePageSize,
             .toggleColumn,
             .selectRow,
             .previousPage,
             .nextPage:
            return true
        case .run,
             .saveCurrentList,
             .refreshSavedLists,
             .deleteSavedList,
             .importSavedListsJSON,
             .exportSelectedSavedListJSON,
             .exportAllSavedListsJSON,
             .importReferenceWordList,
             .exportRowContext,
             .openFocusKWIC,
             .openReferenceKWIC,
             .openCompareDistribution:
            return false
        }
    }
}
