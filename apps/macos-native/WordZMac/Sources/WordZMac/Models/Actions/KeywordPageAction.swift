import Foundation

enum KeywordPageAction {
    case run
    case changeTargetCorpus(String)
    case changeReferenceCorpus(String)
    case changeStatistic(KeywordStatisticMethod)
    case changeSort(KeywordSortMode)
    case sortByColumn(KeywordColumnKey)
    case changePageSize(KeywordPageSize)
    case toggleColumn(KeywordColumnKey)
    case selectRow(String?)
    case previousPage
    case nextPage
}
