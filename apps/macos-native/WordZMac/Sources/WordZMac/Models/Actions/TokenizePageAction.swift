import Foundation

enum TokenizePageAction {
    case run
    case exportText
    case changeSort(TokenizeSortMode)
    case sortByColumn(TokenizeColumnKey)
    case changePageSize(TokenizePageSize)
    case toggleColumn(TokenizeColumnKey)
    case selectRow(String?)
    case previousPage
    case nextPage
}
