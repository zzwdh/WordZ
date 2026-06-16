import Foundation

extension KWICPageViewModel {
    func resolvedFilteredRows(for result: KWICResult) -> [KWICRow] {
        if let cachedFilteredRows,
           cachedStopwordFilter == stopwordFilter,
           cachedSourceFilterQuery == sourceFilterQuery {
            return cachedFilteredRows
        }
        let filteredRows = sceneBuilder.filterRows(
            from: result.rows,
            stopwordFilter: stopwordFilter,
            sourceFilterQuery: sourceFilterQuery
        )
        cachedFilteredRows = filteredRows
        cachedStopwordFilter = stopwordFilter
        cachedSourceFilterQuery = sourceFilterQuery
        invalidateSortedRowsCache()
        return filteredRows
    }

    func resolvedSortedRows(_ rows: [KWICRow]) -> [KWICRow] {
        if let cachedSortedRows,
           cachedSortMode == sortMode {
            return cachedSortedRows
        }
        let sortedRows = sceneBuilder.sortRows(rows, mode: sortMode)
        cachedSortedRows = sortedRows
        cachedSortMode = sortMode
        return sortedRows
    }

    func invalidateCaches() {
        cachedFilteredRows = nil
        cachedStopwordFilter = .default
        cachedSourceFilterQuery = ""
        invalidateSortedRowsCache()
    }

    func invalidateSortedRowsCache() {
        cachedSortedRows = nil
        cachedSortMode = nil
    }
}
