import Foundation

enum TopicsPageAction {
    case run
    case selectCluster(String)
    case changeSort(TopicSegmentSortMode)
    case sortByColumn(TopicsColumnKey)
    case changePageSize(TopicsPageSize)
    case toggleColumn(TopicsColumnKey)
    case previousPage
    case nextPage
    case exportSummary
    case exportSegments
}
