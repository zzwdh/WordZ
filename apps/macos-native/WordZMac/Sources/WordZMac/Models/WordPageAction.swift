import Foundation

enum WordPageAction {
    case run
    case changeSort(WordSortMode)
    case sortByColumn(WordColumnKey)
    case changePageSize(WordPageSize)
    case toggleColumn(WordColumnKey)
    case previousPage
    case nextPage
}
