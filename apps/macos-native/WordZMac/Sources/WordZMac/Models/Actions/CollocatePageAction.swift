import Foundation

enum CollocatePageAction {
    case run
    case openKWIC
    case applyPreset(CollocatePreset)
    case changeFocusMetric(CollocateAssociationMetric)
    case changeSort(CollocateSortMode)
    case sortByColumn(CollocateColumnKey)
    case changePageSize(CollocatePageSize)
    case toggleColumn(CollocateColumnKey)
    case selectRow(String?)
    case copyCurrent(ReadingExportFormat)
    case copyVisible(ReadingExportFormat)
    case copyMethodSummary
    case exportCurrent(ReadingExportFormat)
    case exportVisible(ReadingExportFormat)
    case previousPage
    case nextPage
}
