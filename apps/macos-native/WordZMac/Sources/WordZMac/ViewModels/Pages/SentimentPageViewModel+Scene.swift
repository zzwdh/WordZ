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
        guard let presentationResult else { return nil }
        if let selectedRowID,
           let row = presentationResult.effectiveRows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return presentationResult.effectiveRows.first
    }

    var selectedResultRow: SentimentRowResult? {
        guard let rawResult else { return nil }
        if let selectedRowID,
           let row = rawResult.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return rawResult.rows.first
    }

    var selectedReviewSample: SentimentReviewSample? {
        guard let selectedResultRow,
              let rawResult
        else { return nil }
        let matchKey = SentimentReviewMatchKey.make(request: rawResult.request, row: selectedResultRow)
        return reviewSamples
            .filter { $0.matchKey == matchKey }
            .max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.id < rhs.id
                }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    var result: SentimentRunResult? {
        rawResult
    }

    var canOpenSelectedRowSourceReader: Bool {
        guard let selectedResultRow else { return false }
        return selectedResultRow.sourceID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            selectedResultRow.sentenceID != nil
    }

    func exportMetadataLines(
        annotationSummary: String,
        languageMode: AppLanguageMode
    ) -> [String] {
        let effectivePackID = rawResult?.request.resolvedDomainPackID ?? currentPackRecommendation.effectivePackID
        var lines: [String] = [
            "\(wordZText("规则包", "Domain Pack", mode: languageMode)): \(rawResult?.request.domainPackSummary(in: languageMode) ?? currentPackRecommendation.summary(in: languageMode))",
            "\(wordZText("规则配置", "Rule Profile", mode: languageMode)): \(selectedRuleProfile.title)",
            "\(wordZText("校准配置", "Calibration Profile", mode: languageMode)): \(selectedCalibrationProfileTitle(in: languageMode))",
            "\(wordZText("Review Filter", "Review Filter", mode: languageMode)): \(reviewFilter.title(in: languageMode))",
            "\(wordZText("审校状态", "Review Status", mode: languageMode)): \(reviewStatusFilter.title(in: languageMode))"
        ]

        if !selectedRuleProfile.importedBundleIDs.isEmpty {
            lines.append(
                "\(wordZText("用户词典", "User Lexicon Bundles", mode: languageMode)): \(selectedRuleProfile.importedBundleIDs.joined(separator: ", "))"
            )
        }
        lines.append(
            "\(wordZText("当前 Pack Bias", "Current Pack Bias", mode: languageMode)): \(String(format: "%.2f", selectedCalibrationProfile.domainBiasAdjustments[effectivePackID.rawValue] ?? 0))"
        )

        if showOnlyHardCases {
            lines.append(wordZText("仅显示难例", "Showing hard cases only", mode: languageMode))
        }

        if let reviewSummary = presentationResult?.reviewSummary {
            lines.append(
                "\(wordZText("已审校样本", "Reviewed Samples", mode: languageMode)): \(reviewSummary.reviewedCount)"
            )
            lines.append(
                "\(wordZText("人工改标", "Overrides", mode: languageMode)): \(reviewSummary.overriddenCount)"
            )
            lines.append(
                "\(wordZText("确认原判", "Confirmed Raw", mode: languageMode)): \(reviewSummary.confirmedRawCount)"
            )
        }

        switch source {
        case .corpusCompare:
            lines.append(
                "\(wordZText("跨分析", "Cross Analysis", mode: languageMode)): \(wordZText("Compare x Sentiment", "Compare x Sentiment", mode: languageMode))"
            )
            lines.append(
                "\(wordZText("范围", "Scope", mode: languageMode)): \(corpusCompareScopeSummary(in: languageMode))"
            )
            let focusTerm = rowFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !focusTerm.isEmpty {
                lines.append(
                    "\(wordZText("聚焦词项", "Focus Term", mode: languageMode)): \(focusTerm)"
                )
            }
        case .topicSegments:
            lines.append(
                "\(wordZText("跨分析", "Cross Analysis", mode: languageMode)): \(wordZText("Topics x Sentiment", "Topics x Sentiment", mode: languageMode))"
            )
            lines.append(
                "\(wordZText("范围", "Scope", mode: languageMode)): \(topicSegmentScopeSummary(in: languageMode))"
            )
            if let focusedTopicID = topicSegmentsFocusClusterID,
               !focusedTopicID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(
                    "\(wordZText("聚焦主题", "Focused Topic", mode: languageMode)): \(focusedTopicID)"
                )
            }

            let visibleGroups = orderedTopicGroupTitles()
            if !visibleGroups.isEmpty {
                lines.append(
                    "\(wordZText("主题范围", "Topic Scope", mode: languageMode)): \(visibleGroups.joined(separator: " · "))"
                )
            }
        default:
            break
        }

        let trimmedAnnotationSummary = annotationSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAnnotationSummary.isEmpty {
            lines.append(trimmedAnnotationSummary)
        }

        return lines
    }

    func currentRunRequest(texts: [SentimentInputText]) -> SentimentRunRequest {
        let packRecommendation = packRecommendationService.resolve(
            selectedPackID: selectedDomainPackID,
            source: source,
            texts: texts
        )
        return SentimentRunRequest(
            source: source,
            unit: unit,
            contextBasis: contextBasis,
            thresholds: thresholds,
            texts: texts,
            backend: backend,
            domainPackID: selectedDomainPackID,
            effectiveDomainPackID: packRecommendation.usesAutomaticSelection ? packRecommendation.effectivePackID : nil,
            ruleProfile: selectedRuleProfile,
            calibrationProfile: currentCalibrationProfile,
            userLexiconBundleIDs: selectedRuleProfile.importedBundleIDs
        )
    }

    func rebuildScene() {
        guard let presentationResult else {
            scene = nil
            return
        }
        let trimmedQuery = rowFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let rowsForSelection = presentationResult.effectiveRows.filter { row in
            let rawRow = row.rawRow
            let matchesLabel = labelFilter.map { row.effectiveLabel == $0 } ?? true
            let matchesReview = reviewFilter.includes(rawRow)
            let matchesReviewStatus = reviewStatusFilter.includes(row)
            let matchesHardCase = showOnlyHardCases
                ? rawRow.diagnostics.reviewFlags.isEmpty == false || rawRow.mixedEvidence
                : true
            let matchesQuery: Bool
            if trimmedQuery.isEmpty {
                matchesQuery = true
            } else {
                let haystacks = [
                    rawRow.text,
                    rawRow.sourceTitle,
                    rawRow.groupTitle ?? "",
                    rawRow.evidence.map(\.surface).joined(separator: " "),
                    rawRow.diagnostics.ruleSummary ?? "",
                    rawRow.diagnostics.scopeNotes.joined(separator: " "),
                    rawRow.diagnostics.ruleTraces.flatMap(\.appliedSteps).map(\.note).joined(separator: " "),
                    row.reviewNote ?? ""
                ].map { $0.localizedLowercase }
                matchesQuery = haystacks.contains { $0.contains(trimmedQuery.localizedLowercase) }
            }
            return matchesLabel && matchesReview && matchesReviewStatus && matchesHardCase && matchesQuery
        }
        syncSelectedRow(within: rowsForSelection)
        syncSelectedReviewNoteDraft()
        scene = sceneBuilder.build(
            from: presentationResult,
            thresholdPreset: thresholdPreset,
            filterQuery: rowFilterQuery,
            labelFilter: labelFilter,
            reviewFilter: reviewFilter,
            reviewStatusFilter: reviewStatusFilter,
            showOnlyHardCases: showOnlyHardCases,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            selectedRowID: selectedRowID,
            chartKind: chartKind,
            additionalMetadataLines: exportMetadataLines(
                annotationSummary: annotationState.summary(in: WordZLocalization.shared.effectiveMode),
                languageMode: WordZLocalization.shared.effectiveMode
            ),
            languageMode: WordZLocalization.shared.effectiveMode
        )
        currentPage = scene?.pagination.currentPage ?? 1
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
        sortMode = .original
        pageSize = .fifty
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        selectedRowID = nil
        rawResult = nil
        presentationResult = nil
        reviewSamples = []
        scene = nil
        backendNotice = nil
        selectedReviewNoteDraft = ""
        selectedReferenceSelection = .automatic
        topicSegmentsFocusClusterID = nil
        selectedCorpusIDs = selectedCorpusIDs.isEmpty ? [] : selectedCorpusIDs
        refreshAvailableBackends()
        rebuildCorpusOptions()
    }

    func applyReviewSamples(_ samples: [SentimentReviewSample]) {
        reviewSamples = latestReviewSamples(samples)
        rebuildPresentationResult(rebuildScene: true)
    }

    func makeSelectedReviewSample(decision: SentimentReviewDecision) -> SentimentReviewSample? {
        guard let selectedResultRow,
              let rawResult
        else {
            return nil
        }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return SentimentReviewOverlaySupport.makeReviewSample(
            decision: decision,
            row: selectedResultRow,
            result: rawResult,
            note: selectedReviewNoteDraft,
            timestamp: timestamp,
            existingSample: selectedReviewSample
        )
    }

    private func rebuildPresentationResult(rebuildScene shouldRebuildScene: Bool) {
        presentationResult = rawResult.map { rawResult in
            SentimentReviewOverlaySupport.makePresentationResult(
                rawResult: rawResult,
                reviewSamples: reviewSamples
            )
        }
        if shouldRebuildScene {
            rebuildScene()
        } else {
            syncSelectedReviewNoteDraft()
        }
    }

    private func latestReviewSamples(_ samples: [SentimentReviewSample]) -> [SentimentReviewSample] {
        let grouped = Dictionary(grouping: samples, by: \.matchKey)
        return grouped.values.compactMap { group in
            group.max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.id < rhs.id
                }
                return lhs.updatedAt < rhs.updatedAt
            }
        }
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.id > rhs.id
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func syncSelectedReviewNoteDraft() {
        let nextValue = selectedReviewSample?.reviewNote ?? ""
        if selectedReviewNoteDraft != nextValue {
            selectedReviewNoteDraft = nextValue
        }
    }
}
