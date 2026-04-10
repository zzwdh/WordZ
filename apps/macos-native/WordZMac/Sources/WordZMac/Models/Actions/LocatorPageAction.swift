import Foundation

enum LocatorPageAction: Equatable {
    case run
    case changePageSize(LocatorPageSize)
    case toggleColumn(LocatorColumnKey)
    case selectRow(String?)
    case activateRow(String)
    case copyCurrent(ReadingExportFormat)
    case copyVisible(ReadingExportFormat)
    case exportCurrent(ReadingExportFormat)
    case exportVisible(ReadingExportFormat)
    case previousPage
    case nextPage
}
