import Foundation

enum ClusterPageAction {
    case run
    case openKWIC
    case changeMode(ClusterMode)
    case changeReferenceCorpus(String?)
    case changeSelectedN(Int)
    case changeMinFrequency(String)
    case changeSort(ClusterSortMode)
    case sortByColumn(ClusterColumnKey)
    case changePageSize(ClusterPageSize)
    case changeCaseSensitive(Bool)
    case changePunctuationMode(ClusterPunctuationMode)
    case toggleColumn(ClusterColumnKey)
    case previousPage
    case nextPage
    case selectRow(String?)
    case activateRow(String)
}
