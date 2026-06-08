import Foundation

extension SentimentPageViewModel {
    func handle(_ action: SentimentPageAction) {
        switch action {
        case .run,
             .openSourceReader,
             .exportSummary,
             .exportStructuredJSON,
             .confirmSelectedRow,
             .overrideSelectedRow,
             .clearSelectedRowReview:
            return
        case .changeSource(let nextSource):
            source = nextSource
        case .changeUnit(let nextUnit):
            unit = nextUnit
        case .changeContextBasis(let nextBasis):
            contextBasis = nextBasis
        case .changeBackend(let nextBackend):
            backend = normalizedBackend(nextBackend)
        case .changeDomainPack(let packID):
            selectedDomainPackID = packID
        case .changeRuleProfile(let profileID):
            selectedRuleProfileID = profileID
        case .changeCalibrationProfile(let calibrationProfileID):
            selectedCalibrationProfileID = calibrationProfileID
        case .changeChartKind(let nextKind):
            chartKind = nextKind
        case .changeThresholdPreset(let nextPreset):
            thresholdPreset = nextPreset
        case .changeDecisionThreshold(let value):
            decisionThreshold = value
        case .changeMinimumEvidence(let value):
            minimumEvidence = value
        case .changeNeutralBias(let value):
            neutralBias = value
        case .changeFilterQuery(let value):
            rowFilterQuery = value
        case .changeLabelFilter(let nextFilter):
            labelFilter = nextFilter
        case .changeReviewFilter(let nextFilter):
            reviewFilter = nextFilter
        case .changeReviewStatusFilter(let nextFilter):
            reviewStatusFilter = nextFilter
        case .toggleShowOnlyHardCases(let enabled):
            showOnlyHardCases = enabled
        case .changeSelectedRowReviewNote(let note):
            selectedReviewNoteDraft = note
        case .importUserLexiconBundle:
            return
        case .removeUserLexiconBundle(let bundleID):
            removeUserLexiconBundle(bundleID)
        case .changeSort(let nextSort):
            applyTableSortModeChange(nextSort)
        case .sortByColumn(let column):
            sortTableByColumn(column)
        case .changePageSize(let nextPageSize):
            applyTablePageSizeChange(nextPageSize)
        case .previousPage:
            goToPreviousTablePage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextTablePage(canGoForward: scene?.pagination.canGoForward == true)
        case .toggleColumn(let column):
            toggleTableColumnAndRebuild(column)
        case .selectRow(let rowID):
            let updateScope = applySelectionOnlyUpdate(rowID, within: scene?.rows ?? [])
            guard updateScope == .selectionOnly else { return }
            syncSelectedReviewNoteDraft()
        case .changeManualText(let text):
            manualText = text
        case .toggleCorpusSelection(let corpusID):
            if selectedCorpusIDs.contains(corpusID) {
                selectedCorpusIDs.remove(corpusID)
            } else {
                selectedCorpusIDs.insert(corpusID)
            }
            normalizeReferenceSelection()
            rebuildCorpusOptions()
            handleInputChange(rebuildScene: false)
        case .changeReferenceCorpus(let corpusID):
            selectedReferenceSelection = CompareReferenceSelection(optionID: corpusID)
            rebuildCorpusOptions()
            handleInputChange(rebuildScene: false)
        }
    }

    func importUserLexiconBundle(_ bundle: SentimentUserLexiconBundle) {
        isApplyingState = true
        var updatedBundles = importedLexiconBundles
        if let existingIndex = updatedBundles.firstIndex(where: { $0.id == bundle.id }) {
            updatedBundles[existingIndex] = bundle
        } else {
            updatedBundles.append(bundle)
        }
        importedLexiconBundles = updatedBundles
        selectedRuleProfileID = bundleRuleProfileID(for: bundle.id)
        isApplyingState = false
        handleInputChange(rebuildScene: true)
    }

    func removeUserLexiconBundle(_ bundleID: String) {
        guard importedLexiconBundles.contains(where: { $0.id == bundleID }) else { return }
        let wasSelected = selectedRuleProfileID == bundleRuleProfileID(for: bundleID)
        isApplyingState = true
        importedLexiconBundles.removeAll { $0.id == bundleID }
        if wasSelected {
            selectedRuleProfileID = configuredDefaultRuleProfile.id
        }
        normalizeSelectedRuleProfileSelection()
        isApplyingState = false
        handleInputChange(rebuildScene: true)
    }

    func clampUnitForSource() {
        if !supportedUnits.contains(unit) {
            unit = supportedUnits.first ?? .sentence
        }
    }

    func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        propagateInputChange(rebuildScene: shouldRebuildScene) {
            rebuildScene()
        }
    }

    func nextSortMode(
        for column: SentimentColumnKey,
        currentSortMode _: SentimentSortMode
    ) -> SentimentSortMode? {
        switch column {
        case .positivity:
            return .positivityDescending
        case .neutrality:
            return .neutralityDescending
        case .negativity:
            return .negativityDescending
        case .netScore:
            return .netScoreDescending
        case .finalLabel:
            return .labelAscending
        case .rawLabel:
            return .labelAscending
        case .reviewStatus:
            return .reviewStatusAscending
        case .source:
            return .sourceAscending
        case .text, .evidence:
            return .original
        }
    }

    func markThresholdsCustom() {
        guard !isApplyingState, !isApplyingThresholdBatch else { return }
        if thresholdPreset != .custom,
           thresholds != thresholdPreset.thresholds {
            isApplyingThresholdBatch = true
            thresholdPreset = .custom
            isApplyingThresholdBatch = false
        }
    }

    func applyThresholds(_ thresholds: SentimentThresholds, rebuildScene: Bool) {
        isApplyingThresholdBatch = true
        decisionThreshold = thresholds.decisionThreshold
        minimumEvidence = thresholds.minimumEvidence
        neutralBias = thresholds.neutralBias
        isApplyingThresholdBatch = false
        if rebuildScene {
            handleInputChange(rebuildScene: true)
        }
    }
}
