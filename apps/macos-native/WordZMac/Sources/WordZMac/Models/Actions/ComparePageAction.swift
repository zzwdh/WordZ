import Foundation

enum ComparePageAction: Equatable {
    case run
    case toggleCorpusSelection(String)
    case changeReferenceCorpus(String?)
    case changeSort(CompareSortMode)
    case sortByColumn(CompareColumnKey)
    case changePageSize(ComparePageSize)
    case toggleColumn(CompareColumnKey)
    case selectRow(String?)
    case copyCurrent(ReadingExportFormat)
    case copyVisible(ReadingExportFormat)
    case exportCurrent(ReadingExportFormat)
    case exportVisible(ReadingExportFormat)
    case previousPage
    case nextPage
}
