import Foundation

enum KWICPageAction {
    case run
    case changeSort(KWICSortMode)
    case sortByColumn(KWICColumnKey)
    case changePageSize(KWICPageSize)
    case toggleColumn(KWICColumnKey)
    case selectRow(String?)
    case activateRow(String)
    case copyCurrent(ReadingExportFormat)
    case copyVisible(ReadingExportFormat)
    case exportCurrent(ReadingExportFormat)
    case exportVisible(ReadingExportFormat)
    case previousPage
    case nextPage
}
