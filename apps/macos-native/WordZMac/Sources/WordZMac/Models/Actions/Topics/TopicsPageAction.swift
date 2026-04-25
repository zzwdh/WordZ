import Foundation

enum TopicsSentimentDrilldownScope: Equatable {
    case visibleTopics
    case selectedTopic
}

enum TopicsPageAction {
    case run
    case selectCluster(String)
    case selectRow(String?)
    case activateRow(String)
    case openSourceReader
    case openKWIC
    case openSentiment(TopicsSentimentDrilldownScope)
    case openSentimentExemplar(String)
    case openSentimentSourceReader(String)
    case changeSort(TopicSegmentSortMode)
    case sortByColumn(TopicsColumnKey)
    case changePageSize(TopicsPageSize)
    case toggleColumn(TopicsColumnKey)
    case previousPage
    case nextPage
    case exportSummary
    case exportSegments
}
