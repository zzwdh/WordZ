import Foundation

extension ComparePageViewModel {
    func resolvedFilteredRows(for result: CompareResult) -> (rows: [CompareRow], error: String) {
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
        invalidateDerivedRowsCache()
        return filtered
    }

    func resolvedDerivedRows(
        _ rows: [CompareRow],
        languageMode: AppLanguageMode
    ) -> [DerivedCompareRow] {
        if let cachedDerivedRows,
           cachedDerivedReferenceSelection == selectedReferenceSelection,
           cachedDerivedReferenceCorpusSets == availableCorpusSets,
           cachedDerivedLanguageMode == languageMode {
            return cachedDerivedRows
        }
        let derivedRows = sceneBuilder.buildDerivedRows(
            from: rows,
            referenceSelection: selectedReferenceSelection,
            referenceCorpusSets: availableCorpusSets,
            languageMode: languageMode
        )
        cachedDerivedRows = derivedRows
        cachedDerivedReferenceSelection = selectedReferenceSelection
        cachedDerivedReferenceCorpusSets = availableCorpusSets
        cachedDerivedLanguageMode = languageMode
        invalidateSortedRowsCache()
        return derivedRows
    }

    func resolvedSortedRows(_ rows: [DerivedCompareRow]) -> [DerivedCompareRow] {
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
        invalidateDerivedRowsCache()
    }

    func invalidateDerivedRowsCache() {
        cachedDerivedRows = nil
        cachedDerivedReferenceSelection = nil
        cachedDerivedReferenceCorpusSets = []
        cachedDerivedLanguageMode = nil
        invalidateSortedRowsCache()
    }

    func invalidateSortedRowsCache() {
        cachedSortedRows = nil
        cachedSortMode = nil
    }
}
