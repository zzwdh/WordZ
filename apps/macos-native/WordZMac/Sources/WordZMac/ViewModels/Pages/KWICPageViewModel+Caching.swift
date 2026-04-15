import Foundation

extension KWICPageViewModel {
    func resolvedFilteredRows(for result: KWICResult) -> [KWICRow] {
        if let cachedFilteredRows,
           cachedStopwordFilter == stopwordFilter {
            return cachedFilteredRows
        }
        let filteredRows = sceneBuilder.filterRows(
            from: result.rows,
            stopwordFilter: stopwordFilter
        )
        cachedFilteredRows = filteredRows
        cachedStopwordFilter = stopwordFilter
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
        invalidateSortedRowsCache()
    }

    func invalidateSortedRowsCache() {
        cachedSortedRows = nil
        cachedSortMode = nil
    }
}
