import Foundation

extension KeywordPageViewModel {
    func estimatedSceneBuildRowCount(
        result: KeywordSuiteResult?,
        activeTab: KeywordSuiteTab,
        listMode: KeywordSavedListViewMode,
        primarySavedList: KeywordSavedList?,
        secondarySavedList: KeywordSavedList?,
        savedLists: [KeywordSavedList]
    ) -> Int {
        switch activeTab {
        case .words:
            result?.words.count ?? 0
        case .terms:
            result?.terms.count ?? 0
        case .ngrams:
            result?.ngrams.count ?? 0
        case .lists:
            switch listMode {
            case .pairwiseDiff:
                (primarySavedList?.rows.count ?? 0) + (secondarySavedList?.rows.count ?? 0)
            case .keywordDatabase:
                savedLists.reduce(0) { $0 + $1.rows.count }
            }
        }
    }

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
            invalidatePendingSceneBuilds()
            scene = nil
            selectedRowID = nil
            return
        }

        let revision = beginSceneBuildPass()
        let resultSnapshot = result
        let activeTabSnapshot = activeTab
        let listModeSnapshot = savedListViewMode
        let primarySavedListSnapshot = selectedSavedList
        let secondarySavedListSnapshot = comparisonSavedList
        let savedListsSnapshot = savedLists
        let configurationSnapshot = suiteConfiguration
        let annotationStateSnapshot = workspaceAnnotationState
        let focusSelectionSummarySnapshot = focusSelectionSummary
        let referenceSelectionSummarySnapshot = referenceSelectionSummary
        let hasPendingRunChangesSnapshot = hasPendingRunChanges
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let rowCount = estimatedSceneBuildRowCount(
            result: resultSnapshot,
            activeTab: activeTabSnapshot,
            listMode: listModeSnapshot,
            primarySavedList: primarySavedListSnapshot,
            secondarySavedList: secondarySavedListSnapshot,
            savedLists: savedListsSnapshot
        )

        let applyScene: (KeywordSceneModel) -> Void = { nextScene in
            self.scene = nextScene
            self.currentPage = nextScene.pagination.currentPage
            self.syncSelectedRow(within: nextScene.rows)
        }

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let nextScene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "keyword", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    result: resultSnapshot,
                    activeTab: activeTabSnapshot,
                    listMode: listModeSnapshot,
                    primarySavedList: primarySavedListSnapshot,
                    secondarySavedList: secondarySavedListSnapshot,
                    savedLists: savedListsSnapshot,
                    configuration: configurationSnapshot,
                    annotationState: annotationStateSnapshot,
                    focusSelectionSummary: focusSelectionSummarySnapshot,
                    referenceSelectionSummary: referenceSelectionSummarySnapshot,
                    hasPendingRunChanges: hasPendingRunChangesSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot
                )
            }
            applyScene(nextScene)
            return
        }

        AnalysisSceneBuildScheduling.schedule(
            owner: self,
            context: .init(page: "keyword", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                try Task.checkCancellation()
                let nextScene = sceneBuilder.build(
                    result: resultSnapshot,
                    activeTab: activeTabSnapshot,
                    listMode: listModeSnapshot,
                    primarySavedList: primarySavedListSnapshot,
                    secondarySavedList: secondarySavedListSnapshot,
                    savedLists: savedListsSnapshot,
                    configuration: configurationSnapshot,
                    annotationState: annotationStateSnapshot,
                    focusSelectionSummary: focusSelectionSummarySnapshot,
                    referenceSelectionSummary: referenceSelectionSummarySnapshot,
                    hasPendingRunChanges: hasPendingRunChangesSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot
                )
                try Task.checkCancellation()
                return nextScene
            },
            apply: { nextScene in
                guard self.isCurrentSceneBuild(revision) else { return false }
                applyScene(nextScene)
                return true
            }
        )
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
