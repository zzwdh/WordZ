import Foundation

extension CollocatePageViewModel {
    func resolvedFilteredRows(for result: CollocateResult) -> [CollocateRow] {
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

    func resolvedSortedRows(_ rows: [CollocateRow]) -> [CollocateRow] {
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
