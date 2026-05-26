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
            applyTableSortModeChange(nextSort)
        case .sortByColumn(let column):
            sortTableByColumn(column)
        case .changePageSize(let nextPageSize):
            applyTablePageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleTableColumnAndRebuild(column)
        case .selectRow(let rowID):
            selectedRowID = rowID
        case .previousPage:
            goToPreviousTablePage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextTablePage(canGoForward: scene?.pagination.canGoForward == true)
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

    func nextSortMode(
        for column: KeywordColumnKey,
        currentSortMode _: KeywordSortMode
    ) -> KeywordSortMode? {
        switch column {
        case .item:
            return .alphabeticalAscending
        case .keyness, .direction, .pValue:
            return .keynessDescending
        case .logRatio, .logRatioDelta, .meanAbsLogRatio:
            return .absLogRatioDescending
        case .focusFrequency, .referenceFrequency:
            return .focusFrequencyDescending
        case .focusNormFrequency, .referenceNormFrequency:
            return .focusNormFrequencyDescending
        case .focusRange, .referenceRange:
            return .focusRangeDescending
        case .coverageCount, .coverageRate:
            return .coverageDescending
        case .lastSeenAt:
            return .updatedAtDescending
        case .meanKeyness:
            return .keynessDescending
        case .rank, .example, .diffStatus, .leftRank, .rightRank:
            return nil
        }
    }
}
