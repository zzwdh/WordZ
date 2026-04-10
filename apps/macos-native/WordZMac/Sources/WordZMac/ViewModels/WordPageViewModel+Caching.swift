import Foundation

extension WordPageViewModel {
    func resolvedFilteredRows(for result: StatsResult) -> (rows: [FrequencyRow], error: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cachedFilteredRows,
           cachedFilterQuery == trimmedQuery,
           cachedFilterOptions == searchOptions,
           cachedStopwordFilter == stopwordFilter {
            return (cachedFilteredRows, cachedFilteredError)
        }
        let filtered = sceneBuilder.filterRows(
            from: result,
            query: trimmedQuery,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter
        )
        cachedFilteredRows = filtered.rows
        cachedFilteredError = filtered.error
        cachedFilterQuery = trimmedQuery
        cachedFilterOptions = searchOptions
        cachedStopwordFilter = stopwordFilter
        invalidateSortedRowsCache()
        return filtered
    }

    func resolvedDisplayableRows(for result: StatsResult) -> [FrequencyRow] {
        if let cachedDisplayableRows {
            return cachedDisplayableRows
        }
        let rows = sceneBuilder.displayableRows(from: result)
        cachedDisplayableRows = rows
        return rows
    }

    func resolvedSortedRows(_ rows: [FrequencyRow]) -> [FrequencyRow] {
        if let cachedSortedRows,
           cachedSortMode == sortMode,
           cachedDefinition == definition {
            return cachedSortedRows
        }
        let sortedRows = sceneBuilder.sortRows(rows, mode: sortMode, definition: definition)
        cachedSortedRows = sortedRows
        cachedSortMode = sortMode
        cachedDefinition = definition
        return sortedRows
    }

    func invalidateCaches() {
        cachedDisplayableRows = nil
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
        cachedDefinition = nil
    }
}
