import Foundation

enum SentimentPageAction {
    case run
    case changeSource(SentimentInputSource)
    case changeUnit(SentimentAnalysisUnit)
    case changeContextBasis(SentimentContextBasis)
    case changeBackend(SentimentBackendKind)
    case changeChartKind(SentimentChartKind)
    case changeThresholdPreset(SentimentThresholdPreset)
    case changeDecisionThreshold(Double)
    case changeMinimumEvidence(Double)
    case changeNeutralBias(Double)
    case changeFilterQuery(String)
    case changeLabelFilter(SentimentLabel?)
    case changeSort(SentimentSortMode)
    case sortByColumn(SentimentColumnKey)
    case changePageSize(SentimentPageSize)
    case toggleColumn(SentimentColumnKey)
    case selectRow(String?)
    case changeManualText(String)
    case toggleCorpusSelection(String)
    case changeReferenceCorpus(String?)
    case exportSummary
    case exportStructuredJSON
}
