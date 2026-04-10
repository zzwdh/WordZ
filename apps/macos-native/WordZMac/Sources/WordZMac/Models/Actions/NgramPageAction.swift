import Foundation

enum NgramPageAction {
    case run
    case changeSort(NgramSortMode)
    case sortByColumn(NgramColumnKey)
    case changePageSize(NgramPageSize)
    case changeSize(Int)
    case toggleColumn(NgramColumnKey)
    case previousPage
    case nextPage
}
