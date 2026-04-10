import Foundation

extension TokenizePageViewModel {
    func resolvedPresetFilteredTokens(for result: TokenizeResult) -> [TokenizedToken] {
        if let cachedPresetFilteredTokens,
           cachedLanguagePreset == languagePreset {
            return cachedPresetFilteredTokens
        }
        let tokens = sceneBuilder.filterPresetTokens(
            from: result,
            languagePreset: languagePreset
        )
        cachedPresetFilteredTokens = tokens
        cachedLanguagePreset = languagePreset
        cachedFilteredTokens = nil
        cachedFilteredError = ""
        cachedFilterQuery = ""
        cachedFilterOptions = .default
        cachedStopwordFilter = .default
        cachedFilterLemmaStrategy = lemmaStrategy
        invalidateSortedRowsCache()
        return tokens
    }

    func resolvedFilteredTokens(for result: TokenizeResult) -> (rows: [TokenizedToken], error: String) {
        let normalizedQuery = AnalysisViewModelSupport.normalizedQuery(query)
        if let cachedFilteredTokens,
           cachedFilterQuery == normalizedQuery,
           cachedFilterOptions == searchOptions,
           cachedStopwordFilter == stopwordFilter,
           cachedFilterLemmaStrategy == lemmaStrategy {
            return (cachedFilteredTokens, cachedFilteredError)
        }
        let filtered = sceneBuilder.filterRows(
            resolvedPresetFilteredTokens(for: result),
            query: normalizedQuery,
            options: searchOptions,
            stopword: stopwordFilter,
            lemmaStrategy: lemmaStrategy
        )
        cachedFilteredTokens = filtered.rows
        cachedFilteredError = filtered.error
        cachedFilterQuery = normalizedQuery
        cachedFilterOptions = searchOptions
        cachedStopwordFilter = stopwordFilter
        cachedFilterLemmaStrategy = lemmaStrategy
        invalidateSortedRowsCache()
        return filtered
    }

    func resolvedSortedTokens(_ rows: [TokenizedToken]) -> [TokenizedToken] {
        if let cachedSortedTokens,
           cachedSortMode == sortMode,
           cachedSortLemmaStrategy == lemmaStrategy {
            return cachedSortedTokens
        }
        let sortedTokens = sceneBuilder.sortRows(
            rows,
            mode: sortMode,
            lemmaStrategy: lemmaStrategy
        )
        cachedSortedTokens = sortedTokens
        cachedSortMode = sortMode
        cachedSortLemmaStrategy = lemmaStrategy
        return sortedTokens
    }

    func invalidateCaches() {
        cachedPresetFilteredTokens = nil
        cachedLanguagePreset = nil
        cachedFilteredTokens = nil
        cachedFilteredError = ""
        cachedFilterQuery = ""
        cachedFilterOptions = .default
        cachedStopwordFilter = .default
        cachedFilterLemmaStrategy = .normalizedSurface
        invalidateSortedRowsCache()
    }

    func invalidateSortedRowsCache() {
        cachedSortedTokens = nil
        cachedSortMode = nil
        cachedSortLemmaStrategy = .normalizedSurface
    }
}
