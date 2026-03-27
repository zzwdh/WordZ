import Foundation

enum ComparePageAction: Equatable {
    case run
    case toggleCorpusSelection(String)
    case changeSort(CompareSortMode)
    case sortByColumn(CompareColumnKey)
    case changePageSize(ComparePageSize)
    case toggleColumn(CompareColumnKey)
    case previousPage
    case nextPage
}
