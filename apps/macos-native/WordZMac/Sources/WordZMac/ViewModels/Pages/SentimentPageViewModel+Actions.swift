import Foundation

extension SentimentPageViewModel {
    func handle(_ action: SentimentPageAction) {
        switch action {
        case .run,
             .openSourceReader,
             .addCurrentRowToEvidenceWorkbench,
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
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleVisibleColumnAndRebuild(column)
        case .selectRow(let rowID):
            selectedRowID = rowID
            rebuildScene()
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

    func sortByColumn(_ column: SentimentColumnKey) {
        let nextSort: SentimentSortMode
        switch column {
        case .positivity:
            nextSort = .positivityDescending
        case .neutrality:
            nextSort = .neutralityDescending
        case .negativity:
            nextSort = .negativityDescending
        case .netScore:
            nextSort = .netScoreDescending
        case .finalLabel:
            nextSort = .labelAscending
        case .rawLabel:
            nextSort = .labelAscending
        case .reviewStatus:
            nextSort = .reviewStatusAscending
        case .source:
            nextSort = .sourceAscending
        case .text, .evidence:
            nextSort = .original
        }
        applySortModeChange(nextSort)
    }

    func markThresholdsCustom() {
        guard !isApplyingState else { return }
        if thresholdPreset != .custom,
           thresholds != thresholdPreset.thresholds {
            thresholdPreset = .custom
        }
    }

    func applyThresholds(_ thresholds: SentimentThresholds, rebuildScene: Bool) {
        decisionThreshold = thresholds.decisionThreshold
        minimumEvidence = thresholds.minimumEvidence
        neutralBias = thresholds.neutralBias
        if rebuildScene {
            self.rebuildScene()
        }
    }
}
