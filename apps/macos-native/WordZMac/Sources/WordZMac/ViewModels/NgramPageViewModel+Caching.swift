import Foundation

extension NgramPageViewModel {
    func resolvedFilteredRows(for result: NgramResult) -> (rows: [NgramRow], error: String) {
        let normalizedQuery = normalizedQuery
        if let cachedFilteredRows,
           cachedFilterQuery == normalizedQuery,
           cachedFilterOptions == searchOptions,
           cachedStopwordFilter == stopwordFilter {
            return (cachedFilteredRows, cachedFilteredError)
        }
        let filtered = sceneBuilder.filterRows(
            from: result,
            query: normalizedQuery,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter
        )
        cachedFilteredRows = filtered.rows
        cachedFilteredError = filtered.error
        cachedFilterQuery = normalizedQuery
        cachedFilterOptions = searchOptions
        cachedStopwordFilter = stopwordFilter
        invalidateSortedRowsCache()
        return filtered
    }

    func resolvedSortedRows(_ rows: [NgramRow]) -> [NgramRow] {
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
        cachedFilteredError = ""
        cachedFilterQuery = ""
        cachedFilterOptions = .default
        cachedStopwordFilter = .default
        invalidateSortedRowsCache()
    }

    func invalidateSortedRowsCache() {
        cachedSortedRows = nil
        cachedSortMode = nil
    }
}
