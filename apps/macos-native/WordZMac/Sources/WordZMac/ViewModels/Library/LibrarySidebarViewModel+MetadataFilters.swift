import Foundation

@MainActor
extension LibrarySidebarViewModel {
    var metadataFilterState: CorpusMetadataFilterState {
        CorpusMetadataFilterState(
            sourceQuery: metadataSourceQuery,
            yearQuery: legacyMetadataYearQuery,
            yearFrom: metadataYearFromQuery,
            yearTo: metadataYearToQuery,
            genreQuery: metadataGenreQuery,
            tagsQuery: metadataTagsQuery
        )
    }

    var filteredCorpora: [LibraryCorpusItem] {
        let state = metadataFilterState
        return librarySnapshot.corpora.filter { corpus in
            let corpusSetMatches = selectedCorpusSet == nil || selectedCorpusSet?.corpusIDs.contains(corpus.id) == true
            let metadataMatches = state.isEmpty || state.matches(corpus.metadata)
            return corpusSetMatches && metadataMatches
        }
    }

    var filteredCorpusCount: Int {
        filteredCorpora.count
    }

    func clearMetadataFilters() {
        applyMetadataFilterState(.empty)
    }

    func handleMetadataFilterEdit(oldValue: String, newValue: String) {
        guard oldValue != newValue, !isApplyingMetadataFilterState else { return }
        if selectedCorpusSetID != nil {
            selectedCorpusSetID = nil
        }
        let selectionChanged = normalizeSelectionForCurrentFilters()
        syncScene()
        onMetadataFilterChange?(selectionChanged)
    }

    func handleYearFilterEdit(oldValue: String, newValue: String) {
        guard oldValue != newValue, !isApplyingMetadataFilterState else { return }
        legacyMetadataYearQuery = ""
        handleMetadataFilterEdit(oldValue: oldValue, newValue: newValue)
    }

    func applyMetadataFilterState(_ state: CorpusMetadataFilterState) {
        guard metadataFilterState != state else { return }
        isApplyingMetadataFilterState = true
        metadataSourceQuery = state.sourceQuery
        metadataYearFromQuery = state.yearFrom ?? ""
        metadataYearToQuery = state.yearTo ?? ""
        metadataGenreQuery = state.genreQuery
        metadataTagsQuery = state.tagsQuery
        legacyMetadataYearQuery = state.yearQuery
        isApplyingMetadataFilterState = false
        let selectionChanged = normalizeSelectionForCurrentFilters()
        syncScene()
        onMetadataFilterChange?(selectionChanged)
    }

    func applyCorpusSet(_ corpusSet: LibraryCorpusSetItem?) {
        selectedCorpusSetID = corpusSet?.id
        if let corpusSet {
            isApplyingMetadataFilterState = true
            metadataSourceQuery = corpusSet.metadataFilterState.sourceQuery
            metadataYearFromQuery = corpusSet.metadataFilterState.yearFrom ?? ""
            metadataYearToQuery = corpusSet.metadataFilterState.yearTo ?? ""
            metadataGenreQuery = corpusSet.metadataFilterState.genreQuery
            metadataTagsQuery = corpusSet.metadataFilterState.tagsQuery
            legacyMetadataYearQuery = corpusSet.metadataFilterState.yearQuery
            isApplyingMetadataFilterState = false
        }
        let selectionChanged = normalizeSelectionForCurrentFilters()
        syncScene()
        onMetadataFilterChange?(selectionChanged)
    }

    func normalizeSelectionForCurrentFilters() -> Bool {
        let previousSelection = selectedCorpusID
        let validIDs = Set(filteredCorpora.map(\.id))
        isApplyingMetadataFilterSelection = true
        defer { isApplyingMetadataFilterSelection = false }

        if let selectedCorpusID, !validIDs.contains(selectedCorpusID) {
            self.selectedCorpusID = filteredCorpora.first?.id
        } else if selectedCorpusID == nil {
            self.selectedCorpusID = filteredCorpora.first?.id
        }
        return previousSelection != selectedCorpusID
    }
}
