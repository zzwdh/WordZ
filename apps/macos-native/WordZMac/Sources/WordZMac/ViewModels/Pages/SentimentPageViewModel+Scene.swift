import Foundation

extension SentimentPageViewModel {
    var selectedSceneRow: SentimentSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    var selectedEffectiveRow: SentimentEffectiveRow? {
        reviewState.selectedEffectiveRow(selectedRowID: selectedRowID)
    }

    var selectedResultRow: SentimentRowResult? {
        reviewState.selectedResultRow(selectedRowID: selectedRowID)
    }

    var selectedReviewSample: SentimentReviewSample? {
        reviewState.selectedReviewSample(selectedRowID: selectedRowID)
    }

    var result: SentimentRunResult? {
        rawResult
    }

    var canOpenSelectedRowSourceReader: Bool {
        guard let selectedResultRow else { return false }
        return selectedResultRow.sourceID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            selectedResultRow.sentenceID != nil
    }

    func rebuildScene() {
        guard let presentationResult else {
            invalidatePendingSceneBuilds()
            scene = nil
            return
        }
        rebuildScene(from: presentationResult)
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        isApplyingState = true
        defer {
            isApplyingState = false
            refreshAvailableBackends()
            clampUnitForSource()
            rebuildCorpusOptions()
            rebuildScene()
        }

        source = snapshot.sentimentSource
        unit = snapshot.sentimentUnit
        contextBasis = snapshot.sentimentContextBasis
        backend = normalizedBackend(snapshot.sentimentBackend)
        selectedDomainPackID = snapshot.sentimentDomainPackID
        selectedRuleProfileID = snapshot.sentimentRuleProfileID
        selectedCalibrationProfileID = snapshot.sentimentCalibrationProfileID
        chartKind = snapshot.sentimentChartKind
        thresholdPreset = snapshot.sentimentThresholdPreset
        decisionThreshold = snapshot.sentimentDecisionThreshold
        minimumEvidence = snapshot.sentimentMinimumEvidence
        neutralBias = snapshot.sentimentNeutralBias
        rowFilterQuery = snapshot.sentimentRowFilterQuery
        labelFilter = snapshot.sentimentLabelFilter
        reviewFilter = snapshot.sentimentReviewFilter
        reviewStatusFilter = snapshot.sentimentReviewStatusFilter
        showOnlyHardCases = snapshot.sentimentShowOnlyHardCases
        workspaceCalibrationProfile = snapshot.sentimentWorkspaceCalibrationProfile
        importedLexiconBundles = snapshot.sentimentImportedLexiconBundles
        let snapshotSelection = Set(snapshot.sentimentSelectedCorpusIDs)
        if !snapshotSelection.isEmpty {
            selectedCorpusIDs = snapshotSelection
        }
        selectedReferenceSelection = CompareReferenceSelection(optionID: snapshot.sentimentReferenceCorpusID)
        normalizeSelectedRuleProfileSelection()
        normalizeSelectedCalibrationProfileSelection()
        syncSelectedReviewNoteDraft()
    }

    func apply(_ result: SentimentRunResult) {
        isApplyingState = true
        defer {
            isApplyingState = false
            refreshAvailableBackends()
            rebuildPresentationResult(rebuildScene: true)
        }
        self.rawResult = result
        source = result.request.source
        unit = result.request.unit
        contextBasis = result.request.contextBasis
        backend = normalizedBackend(result.backendKind)
        selectedDomainPackID = result.request.domainPackID
        selectedRuleProfileID = result.request.ruleProfile.id
        selectedCalibrationProfileID = normalizedCalibrationProfileID(result.request.calibrationProfile.id)
        if selectedCalibrationProfileID == SentimentCalibrationProfile.workspaceDefault.id {
            workspaceCalibrationProfile = result.request.calibrationProfile
        }
        if result.request.backend != result.backendKind {
            backendNotice = wordZText(
                "当前所选模型后端不可用，已自动回退到词典规则后端。",
                "The requested model backend is unavailable, so WordZ fell back to the lexicon backend.",
                mode: .system
            )
        } else {
            backendNotice = nil
        }
        applyThresholds(result.request.thresholds, rebuildScene: false)
        currentPage = 1
        selectedRowID = result.rows.first?.id
        syncSelectedReviewNoteDraft()
        if result.request.source != .topicSegments {
            topicSegmentsFocusClusterID = nil
        }
    }

    func reset() {
        isApplyingState = true
        defer { isApplyingState = false }
        source = .openedCorpus
        unit = .sentence
        contextBasis = .visibleContext
        backend = .lexicon
        chartKind = .distributionBar
        thresholdPreset = .conservative
        applyThresholds(.default, rebuildScene: false)
        selectedDomainPackID = .mixed
        selectedRuleProfileID = SentimentRuleProfile.default.id
        selectedCalibrationProfileID = SentimentCalibrationProfile.default.id
        rowFilterQuery = ""
        labelFilter = nil
        reviewFilter = .all
        reviewStatusFilter = .all
        showOnlyHardCases = false
        workspaceCalibrationProfile = .workspaceDefault
        importedLexiconBundles = []
        manualText = ""
        tablePresentation.reset(
            sortMode: .original,
            pageSize: .fifty,
            visibleColumns: Self.defaultVisibleColumns
        )
        selectedRowID = nil
        reviewState.reset()
        scene = nil
        invalidatePendingSceneBuilds()
        backendNotice = nil
        selectedReviewNoteDraft = ""
        selectedReferenceSelection = .automatic
        topicSegmentsFocusClusterID = nil
        selectedCorpusIDs = selectedCorpusIDs.isEmpty ? [] : selectedCorpusIDs
        refreshAvailableBackends()
        rebuildCorpusOptions()
    }

    func applyReviewSamples(_ samples: [SentimentReviewSample]) {
        reviewState.replaceReviewSamples(samples)
        rebuildPresentationResult(rebuildScene: true)
    }

    func makeSelectedReviewSample(decision: SentimentReviewDecision) -> SentimentReviewSample? {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return reviewState.makeSelectedReviewSample(
            decision: decision,
            selectedRowID: selectedRowID,
            note: selectedReviewNoteDraft,
            timestamp: timestamp
        )
    }

    private func rebuildPresentationResult(rebuildScene shouldRebuildScene: Bool) {
        reviewState.rebuildPresentationResult()
        if shouldRebuildScene {
            rebuildScene()
        } else {
            syncSelectedReviewNoteDraft()
        }
    }

    func syncSelectedReviewNoteDraft() {
        let nextValue = selectedReviewSample?.reviewNote ?? ""
        if selectedReviewNoteDraft != nextValue {
            selectedReviewNoteDraft = nextValue
        }
    }
}
