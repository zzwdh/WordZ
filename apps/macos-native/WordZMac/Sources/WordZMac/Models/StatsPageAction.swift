import Foundation

enum StatsPageAction {
    case run
    case changeSort(StatsSortMode)
    case sortByColumn(StatsColumnKey)
    case changePageSize(StatsPageSize)
    case toggleColumn(StatsColumnKey)
    case previousPage
    case nextPage
}
