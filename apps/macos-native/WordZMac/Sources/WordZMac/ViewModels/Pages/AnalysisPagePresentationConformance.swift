import Foundation

extension StatsPageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = StatsColumnKey
    typealias AnalysisSortMode = StatsSortMode
    typealias AnalysisPageSize = StatsPageSize
}

extension WordPageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = WordColumnKey
    typealias AnalysisSortMode = WordSortMode
    typealias AnalysisPageSize = WordPageSize
}

extension NgramPageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = NgramColumnKey
    typealias AnalysisSortMode = NgramSortMode
    typealias AnalysisPageSize = NgramPageSize
}

extension TokenizePageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = TokenizeColumnKey
    typealias AnalysisSortMode = TokenizeSortMode
    typealias AnalysisPageSize = TokenizePageSize
}

extension KWICPageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = KWICColumnKey
    typealias AnalysisSortMode = KWICSortMode
    typealias AnalysisPageSize = KWICPageSize
}

extension CollocatePageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = CollocateColumnKey
    typealias AnalysisSortMode = CollocateSortMode
    typealias AnalysisPageSize = CollocatePageSize
}

extension ComparePageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = CompareColumnKey
    typealias AnalysisSortMode = CompareSortMode
    typealias AnalysisPageSize = ComparePageSize
}

extension KeywordPageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = KeywordColumnKey
    typealias AnalysisSortMode = KeywordSortMode
    typealias AnalysisPageSize = KeywordPageSize
}

extension SentimentPageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = SentimentColumnKey
}

extension TopicsPageViewModel: AnalysisVersionedTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = TopicsColumnKey
    typealias AnalysisSortMode = TopicSegmentSortMode
    typealias AnalysisPageSize = TopicsPageSize
}

extension ClusterPageViewModel: AnalysisTablePresentationProviding, AnalysisTableColumnSortResolving {
    typealias AnalysisColumn = ClusterColumnKey
}

extension LocatorPageViewModel: AnalysisVersionedPagedPresentationProviding {
    typealias AnalysisColumn = LocatorColumnKey
    typealias AnalysisPageSize = LocatorPageSize
}
