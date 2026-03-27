import Foundation

enum KWICPageAction {
    case run
    case changeSort(KWICSortMode)
    case sortByColumn(KWICColumnKey)
    case changePageSize(KWICPageSize)
    case toggleColumn(KWICColumnKey)
    case selectRow(String?)
    case activateRow(String)
    case previousPage
    case nextPage
}
