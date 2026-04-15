import Foundation

extension KeywordPageViewModel {
    func handle(_ action: KeywordPageAction) {
        guard action.routesThroughViewModel else { return }
        switch action {
        case .changeTargetCorpus(let corpusID):
            let nextCorpusID = corpusID.isEmpty ? nil : corpusID
            guard focusSelectionKind != .singleCorpus || selectedFocusCorpusID != nextCorpusID else { return }
            performSelectionMutation {
                focusSelectionKind = .singleCorpus
                selectedFocusCorpusID = nextCorpusID
            }
        case .changeReferenceCorpus(let corpusID):
            let nextCorpusID = corpusID.isEmpty ? nil : corpusID
            guard referenceSourceKind != .singleCorpus || selectedReferenceCorpusID != nextCorpusID else { return }
            performSelectionMutation {
                referenceSourceKind = .singleCorpus
                selectedReferenceCorpusID = nextCorpusID
            }
        case .changeStatistic(let nextStatistic):
            guard statistic != nextStatistic else { return }
            statistic = nextStatistic
        case .changeTab(let tab):
            activeTab = tab
        case .changeSort(let nextSort):
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleColumn(column)
        case .selectRow(let rowID):
            selectedRowID = rowID
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        case .run, .saveCurrentList, .refreshSavedLists, .deleteSavedList, .importSavedListsJSON, .exportSelectedSavedListJSON, .exportAllSavedListsJSON, .importReferenceWordList, .exportRowContext, .openFocusKWIC, .openReferenceKWIC, .openCompareDistribution:
            assertionFailure("Keyword workflow actions should be dispatched by WorkspaceActionDispatcher.")
        }
    }

    func handleInputChange() {
        propagateInputChange(rebuildScene: true) {
            rebuildScene()
        }
    }

    func toggleFocusCorpusSelection(_ corpusID: String) {
        if selectedFocusCorpusIDs.contains(corpusID) {
            selectedFocusCorpusIDs.remove(corpusID)
        } else {
            selectedFocusCorpusIDs.insert(corpusID)
        }
    }

    func toggleScript(_ script: TokenScript) {
        if selectedScripts.contains(script) {
            selectedScripts.remove(script)
        } else {
            selectedScripts.insert(script)
        }
    }

    func toggleLexicalClass(_ lexicalClass: TokenLexicalClass) {
        if selectedLexicalClasses.contains(lexicalClass) {
            selectedLexicalClasses.remove(lexicalClass)
        } else {
            selectedLexicalClasses.insert(lexicalClass)
        }
    }

    func sortByColumn(_ column: KeywordColumnKey) {
        let nextSort: KeywordSortMode?
        switch column {
        case .item:
            nextSort = .alphabeticalAscending
        case .keyness, .direction, .pValue:
            nextSort = .keynessDescending
        case .logRatio, .logRatioDelta, .meanAbsLogRatio:
            nextSort = .absLogRatioDescending
        case .focusFrequency, .referenceFrequency:
            nextSort = .focusFrequencyDescending
        case .focusNormFrequency, .referenceNormFrequency:
            nextSort = .focusNormFrequencyDescending
        case .focusRange, .referenceRange:
            nextSort = .focusRangeDescending
        case .coverageCount, .coverageRate:
            nextSort = .coverageDescending
        case .lastSeenAt:
            nextSort = .updatedAtDescending
        case .meanKeyness:
            nextSort = .keynessDescending
        case .rank, .example, .diffStatus, .leftRank, .rightRank:
            nextSort = nil
        }
        guard let nextSort else { return }
        applySortModeChange(nextSort)
    }

    func toggleColumn(_ column: KeywordColumnKey) {
        toggleVisibleColumnAndRebuild(column)
    }
}
