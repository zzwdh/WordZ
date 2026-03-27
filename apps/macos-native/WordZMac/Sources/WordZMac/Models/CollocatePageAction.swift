import Foundation

enum CollocatePageAction {
    case run
    case changeSort(CollocateSortMode)
    case sortByColumn(CollocateColumnKey)
    case changePageSize(CollocatePageSize)
    case toggleColumn(CollocateColumnKey)
    case previousPage
    case nextPage
}
