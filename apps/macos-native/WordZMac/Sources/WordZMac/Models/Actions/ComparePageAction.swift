import Foundation

enum ComparePageAction: Equatable {
    case run
    case openKWIC
    case openCollocate
    case openSentiment
    case openSentimentExemplar(String)
    case openSentimentSourceReader(String)
    case openTopics
    case saveCorpusSet
    case analyzeInKeywordSuite
    case toggleCorpusSelection(String)
    case changeReferenceCorpus(String?)
    case changeSort(CompareSortMode)
    case sortByColumn(CompareColumnKey)
    case changePageSize(ComparePageSize)
    case toggleColumn(CompareColumnKey)
    case selectRow(String?)
    case copyCurrent(ReadingExportFormat)
    case copyVisible(ReadingExportFormat)
    case copyMethodSummary
    case exportCurrent(ReadingExportFormat)
    case exportVisible(ReadingExportFormat)
    case previousPage
    case nextPage
}
