import Foundation

extension KeywordPageViewModel {
    func normalizeSelections() {
        let validCorpusIDs = Set(availableCorpora.map(\.id))
        let validCorpusSetIDs = Set(availableCorpusSets.map(\.id))

        if let selectedFocusCorpusID, !validCorpusIDs.contains(selectedFocusCorpusID) {
            self.selectedFocusCorpusID = nil
        }
        if let selectedReferenceCorpusID, !validCorpusIDs.contains(selectedReferenceCorpusID) {
            self.selectedReferenceCorpusID = nil
        }
        if let selectedFocusCorpusSetID, !validCorpusSetIDs.contains(selectedFocusCorpusSetID) {
            self.selectedFocusCorpusSetID = nil
        }
        if let selectedReferenceCorpusSetID, !validCorpusSetIDs.contains(selectedReferenceCorpusSetID) {
            self.selectedReferenceCorpusSetID = nil
        }

        selectedFocusCorpusIDs = selectedFocusCorpusIDs.intersection(validCorpusIDs)

        if selectedFocusCorpusID == nil {
            selectedFocusCorpusID = availableCorpora.first?.id
        }

        if focusSelectionKind == .selectedCorpora, selectedFocusCorpusIDs.isEmpty, let selectedFocusCorpusID {
            selectedFocusCorpusIDs = [selectedFocusCorpusID]
        }

        if focusSelectionKind == .namedCorpusSet, selectedFocusCorpusSetID == nil {
            selectedFocusCorpusSetID = availableCorpusSets.first?.id
        }

        if referenceSourceKind == .namedCorpusSet, selectedReferenceCorpusSetID == nil {
            selectedReferenceCorpusSetID = availableCorpusSets.first?.id
        }

        if referenceSourceKind == .singleCorpus, selectedReferenceCorpusID == selectedFocusCorpusID {
            selectedReferenceCorpusID = availableCorpora.first(where: { $0.id != selectedFocusCorpusID })?.id
        }

        normalizeSavedListSelections()
    }

    func normalizeSavedListSelections() {
        let validSavedListIDs = Set(savedLists.map(\.id))
        if let selectedSavedListID, !validSavedListIDs.contains(selectedSavedListID) {
            self.selectedSavedListID = nil
        }
        if let comparisonSavedListID, !validSavedListIDs.contains(comparisonSavedListID) {
            self.comparisonSavedListID = nil
        }
        if selectedSavedListID == nil {
            selectedSavedListID = savedLists.first?.id
        }
        if comparisonSavedListID == selectedSavedListID {
            comparisonSavedListID = savedLists.first(where: { $0.id != selectedSavedListID })?.id
        }
        if comparisonSavedListID == nil {
            comparisonSavedListID = savedLists.first(where: { $0.id != selectedSavedListID })?.id
        }
    }

    func rebuildScene() {
        guard result != nil || activeTab == .lists else {
            scene = nil
            selectedRowID = nil
            return
        }

        scene = sceneBuilder.build(
            result: result,
            activeTab: activeTab,
            listMode: savedListViewMode,
            primarySavedList: selectedSavedList,
            secondarySavedList: comparisonSavedList,
            savedLists: savedLists,
            configuration: suiteConfiguration,
            focusSelectionSummary: focusSelectionSummary,
            referenceSelectionSummary: referenceSelectionSummary,
            hasPendingRunChanges: hasPendingRunChanges,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            languageMode: WordZLocalization.shared.effectiveMode
        )
        currentPage = scene?.pagination.currentPage ?? 1
        syncSelectedRow()
    }

    func syncSelectedRow() {
        syncSelectedRow(within: scene?.rows ?? [])
    }

    func applyCompareSelection(
        selectedCorpusIDs: [String],
        referenceSelection: CompareReferenceSelection
    ) {
        applyStateChange(rebuildScene: rebuildScene) {
            activeTab = .words
            if selectedCorpusIDs.count <= 1 {
                focusSelectionKind = .singleCorpus
                selectedFocusCorpusID = selectedCorpusIDs.first
                selectedFocusCorpusIDs = Set(selectedCorpusIDs)
            } else {
                focusSelectionKind = .selectedCorpora
                selectedFocusCorpusIDs = Set(selectedCorpusIDs)
                selectedFocusCorpusID = selectedCorpusIDs.first
            }
            switch referenceSelection {
            case .automatic:
                referenceSourceKind = .singleCorpus
                selectedReferenceCorpusID = nil
            case .corpus(let corpusID):
                referenceSourceKind = .singleCorpus
                selectedReferenceCorpusID = corpusID
            case .corpusSet(let corpusSetID):
                referenceSourceKind = .namedCorpusSet
                selectedReferenceCorpusSetID = corpusSetID
            }
            normalizeSelections()
        }
    }
}
