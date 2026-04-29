import Foundation

struct SentimentSceneBuilder {
    func build(
        from result: SentimentRunResult,
        thresholdPreset: SentimentThresholdPreset,
        filterQuery: String,
        labelFilter: SentimentLabel?,
        reviewFilter: SentimentReviewFilter = .all,
        reviewStatusFilter: SentimentReviewStatusFilter = .all,
        showOnlyHardCases: Bool = false,
        sortMode: SentimentSortMode,
        pageSize: SentimentPageSize,
        currentPage: Int,
        visibleColumns: Set<SentimentColumnKey>,
        selectedRowID: String?,
        chartKind: SentimentChartKind,
        additionalMetadataLines: [String] = [],
        languageMode: AppLanguageMode = .system
    ) -> SentimentSceneModel {
        build(
            from: SentimentReviewOverlaySupport.makePresentationResult(
                rawResult: result,
                reviewSamples: []
            ),
            thresholdPreset: thresholdPreset,
            filterQuery: filterQuery,
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
            additionalMetadataLines: additionalMetadataLines,
            languageMode: languageMode
        )
    }

    func build(
        from presentationResult: SentimentPresentationResult,
        thresholdPreset: SentimentThresholdPreset,
        filterQuery: String,
        labelFilter: SentimentLabel?,
        reviewFilter: SentimentReviewFilter = .all,
        reviewStatusFilter: SentimentReviewStatusFilter = .all,
        showOnlyHardCases: Bool = false,
        sortMode: SentimentSortMode,
        pageSize: SentimentPageSize,
        currentPage: Int,
        visibleColumns: Set<SentimentColumnKey>,
        selectedRowID: String?,
        chartKind: SentimentChartKind,
        additionalMetadataLines: [String] = [],
        languageMode: AppLanguageMode = .system
    ) -> SentimentSceneModel {
        let filteredRows = filterRows(
            presentationResult.effectiveRows,
            query: filterQuery,
            labelFilter: labelFilter,
            reviewFilter: reviewFilter,
            reviewStatusFilter: reviewStatusFilter,
            showOnlyHardCases: showOnlyHardCases
        )
        let sortedRows = sortRows(filteredRows, mode: sortMode)
        let pagination = buildPagination(
            totalRows: sortedRows.count,
            currentPage: currentPage,
            pageSize: pageSize,
            languageMode: languageMode
        )
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)
        let sceneRows = pageRows.map(makeSceneRow)
        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                columnKey: SentimentColumnKey.self
            ) {
                NativeTableCell(.source, row.groupTitle.isEmpty ? row.sourceTitle : "\(row.groupTitle) · \(row.sourceTitle)")
                NativeTableCell(.text, row.text)
                NativeTableCell(.positivity, formatPercent(row.rawPositivityScore))
                NativeTableCell(.neutrality, formatPercent(row.rawNeutralityScore))
                NativeTableCell(.negativity, formatPercent(row.rawNegativityScore))
                NativeTableCell(.finalLabel, row.effectiveLabel.title(in: languageMode))
                NativeTableCell(.rawLabel, row.rawLabel.title(in: languageMode))
                NativeTableCell(.reviewStatus, row.reviewStatus.title(in: languageMode))
                NativeTableCell(.netScore, format(row.rawNetScore))
                NativeTableCell(.evidence, row.evidencePreview)
            }
        }

        let filteredSceneRows = sortedRows.map(makeSceneRow)
        let positiveExamples = filteredSceneRows.filter { $0.effectiveLabel == .positive }.prefix(5)
        let neutralExamples = filteredSceneRows.filter { $0.effectiveLabel == .neutral }.prefix(5)
        let negativeExamples = filteredSceneRows.filter { $0.effectiveLabel == .negative }.prefix(5)
        let exportMetadataLines = buildMetadataLines(
            presentationResult: presentationResult,
            thresholdPreset: thresholdPreset,
            additionalMetadataLines: additionalMetadataLines,
            languageMode: languageMode
        )

        let rawResult = presentationResult.rawResult
        let effectiveSummary = presentationResult.effectiveOverallSummary

        return SentimentSceneModel(
            source: rawResult.request.source,
            unit: rawResult.request.unit,
            contextBasis: rawResult.request.contextBasis,
            backend: rawResult.backendKind,
            domainPackID: rawResult.request.resolvedDomainPackID,
            ruleProfileID: rawResult.request.ruleProfile.id,
            backendRevision: rawResult.backendRevision,
            resourceRevision: rawResult.resourceRevision,
            supportsEvidenceHits: rawResult.supportsEvidenceHits,
            thresholdPreset: thresholdPreset,
            thresholds: rawResult.request.thresholds,
            chartKind: chartKind,
            filterQuery: filterQuery,
            labelFilter: labelFilter,
            reviewFilter: reviewFilter,
            reviewStatusFilter: reviewStatusFilter,
            showOnlyHardCases: showOnlyHardCases,
            activePackIDs: rawResult.activePackIDs,
            summary: effectiveSummary,
            groupSummaries: presentationResult.effectiveGroupSummaries,
            reviewSummary: presentationResult.reviewSummary,
            sorting: SentimentSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            totalRows: presentationResult.effectiveRows.count,
            filteredRows: filteredRows.count,
            visibleRows: sceneRows.count,
            selectedRowID: selectedRowID,
            rows: sceneRows,
            positiveExamples: Array(positiveExamples),
            neutralExamples: Array(neutralExamples),
            negativeExamples: Array(negativeExamples),
            chartSegments: [
                SentimentChartSegment(
                    label: .positive,
                    count: effectiveSummary.positiveCount,
                    ratio: effectiveSummary.positiveRatio
                ),
                SentimentChartSegment(
                    label: .neutral,
                    count: effectiveSummary.neutralCount,
                    ratio: effectiveSummary.neutralRatio
                ),
                SentimentChartSegment(
                    label: .negative,
                    count: effectiveSummary.negativeCount,
                    ratio: effectiveSummary.negativeRatio
                )
            ],
            trendPoints: Array(presentationResult.effectiveRows.prefix(60).enumerated().map { offset, row in
                SentimentTrendPoint(
                    index: offset + 1,
                    label: row.effectiveLabel,
                    netScore: row.effectiveScores.netScore,
                    title: row.rawRow.sourceTitle
                )
            }),
            table: NativeTableDescriptor(
                storageKey: "sentiment",
                columnKey: SentimentColumnKey.self,
                defaultDensity: .reading
            ) {
                for key in SentimentColumnKey.allCases {
                    NativeTableColumnSpec(
                        key,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortDirection: sortDirection(for: key, mode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .source || key == .text
                    )
                }
            },
            tableRows: tableRows,
            tableSnapshot: ResultTableSnapshot.stable(rows: tableRows),
            exportMetadataLines: exportMetadataLines
        )
    }

    private func filterRows(
        _ rows: [SentimentEffectiveRow],
        query: String,
        labelFilter: SentimentLabel?,
        reviewFilter: SentimentReviewFilter,
        reviewStatusFilter: SentimentReviewStatusFilter,
        showOnlyHardCases: Bool
    ) -> [SentimentEffectiveRow] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return rows.filter { row in
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
                    row.reviewNote ?? "",
                    row.reviewStatus.title(in: .english),
                    row.rawLabel.rawValue,
                    row.effectiveLabel.rawValue
                ].map { $0.localizedLowercase }
                matchesQuery = haystacks.contains { $0.contains(trimmedQuery.localizedLowercase) }
            }
            return matchesLabel && matchesReview && matchesReviewStatus && matchesHardCase && matchesQuery
        }
    }

    private func sortRows(_ rows: [SentimentEffectiveRow], mode: SentimentSortMode) -> [SentimentEffectiveRow] {
        switch mode {
        case .original:
            return rows
        case .positivityDescending:
            return rows.sorted { compare($0.rawRow.positivityScore, $1.rawRow.positivityScore, lhs: $0, rhs: $1) }
        case .neutralityDescending:
            return rows.sorted { compare($0.rawRow.neutralityScore, $1.rawRow.neutralityScore, lhs: $0, rhs: $1) }
        case .negativityDescending:
            return rows.sorted { compare($0.rawRow.negativityScore, $1.rawRow.negativityScore, lhs: $0, rhs: $1) }
        case .netScoreDescending:
            return rows.sorted { compare($0.rawRow.netScore, $1.rawRow.netScore, lhs: $0, rhs: $1) }
        case .labelAscending:
            return rows.sorted {
                if $0.effectiveLabel.rawValue == $1.effectiveLabel.rawValue {
                    return $0.rawRow.sourceTitle.localizedCaseInsensitiveCompare($1.rawRow.sourceTitle) == .orderedAscending
                }
                return $0.effectiveLabel.rawValue < $1.effectiveLabel.rawValue
            }
        case .reviewStatusAscending:
            return rows.sorted {
                if reviewStatusRank($0.reviewStatus) == reviewStatusRank($1.reviewStatus) {
                    return $0.rawRow.text.localizedCaseInsensitiveCompare($1.rawRow.text) == .orderedAscending
                }
                return reviewStatusRank($0.reviewStatus) < reviewStatusRank($1.reviewStatus)
            }
        case .sourceAscending:
            return rows.sorted {
                let sourceCompare = $0.rawRow.sourceTitle.localizedCaseInsensitiveCompare($1.rawRow.sourceTitle)
                if sourceCompare == .orderedSame {
                    return $0.rawRow.text.localizedCaseInsensitiveCompare($1.rawRow.text) == .orderedAscending
                }
                return sourceCompare == .orderedAscending
            }
        }
    }

    private func reviewStatusRank(_ status: SentimentReviewStatus) -> Int {
        switch status {
        case .overridden:
            return 0
        case .confirmed:
            return 1
        case .unreviewed:
            return 2
        }
    }

    private func compare(
        _ lhsValue: Double,
        _ rhsValue: Double,
        lhs: SentimentEffectiveRow,
        rhs: SentimentEffectiveRow
    ) -> Bool {
        if lhsValue == rhsValue {
            return lhs.rawRow.text.localizedCaseInsensitiveCompare(rhs.rawRow.text) == .orderedAscending
        }
        return lhsValue > rhsValue
    }

    private func makeSceneRow(_ row: SentimentEffectiveRow) -> SentimentSceneRow {
        SentimentSceneRow(
            id: row.id,
            sourceTitle: row.rawRow.sourceTitle,
            groupTitle: row.rawRow.groupTitle ?? "",
            text: row.rawRow.text,
            rawPositivityScore: row.rawRow.positivityScore,
            rawNeutralityScore: row.rawRow.neutralityScore,
            rawNegativityScore: row.rawRow.negativityScore,
            rawLabel: row.rawRow.finalLabel,
            rawNetScore: row.rawRow.netScore,
            effectivePositivityScore: row.effectiveScores.positivityScore,
            effectiveNeutralityScore: row.effectiveScores.neutralityScore,
            effectiveNegativityScore: row.effectiveScores.negativityScore,
            effectiveLabel: row.effectiveLabel,
            effectiveNetScore: row.effectiveScores.netScore,
            evidenceCount: row.rawRow.evidenceCount,
            evidencePreview: evidencePreview(for: row.rawRow),
            evidence: row.rawRow.evidence,
            diagnostics: row.rawRow.diagnostics,
            sentenceID: row.rawRow.sentenceID,
            tokenIndex: row.rawRow.tokenIndex,
            reviewDecision: row.reviewDecision,
            reviewStatus: row.reviewStatus,
            reviewNote: row.reviewNote,
            reviewedAt: row.reviewedAt,
            reviewSampleID: row.reviewSampleID
        )
    }

    private func evidencePreview(for row: SentimentRowResult) -> String {
        if !row.evidence.isEmpty {
            return row.evidence.prefix(3).map { hit in
                "\(hit.surface) (\(format(hit.adjustedScore)))"
            }.joined(separator: ", ")
        }
        if !row.diagnostics.ruleTraces.isEmpty {
            return row.diagnostics.ruleTraces
                .prefix(2)
                .map { trace in
                    let steps = trace.appliedSteps
                        .map(\.tag)
                        .filter { $0 != "cueMatched" }
                        .joined(separator: "/")
                    return steps.isEmpty ? trace.cueSurface : "\(trace.cueSurface) [\(steps)]"
                }
                .joined(separator: ", ")
        }
        if let confidence = row.diagnostics.confidence {
            if let topMargin = row.diagnostics.topMargin {
                return "confidence \(formatPercent(confidence)) · margin \(format(topMargin))"
            }
            return "confidence \(formatPercent(confidence))"
        }
        if let ruleSummary = row.diagnostics.ruleSummary, !ruleSummary.isEmpty {
            return ruleSummary
        }
        return "—"
    }

    private func buildMetadataLines(
        presentationResult: SentimentPresentationResult,
        thresholdPreset: SentimentThresholdPreset,
        additionalMetadataLines: [String],
        languageMode: AppLanguageMode
    ) -> [String] {
        let rawResult = presentationResult.rawResult
        var lines = [
            "\(wordZText("来源", "Source", mode: languageMode)): \(rawResult.request.source.title(in: languageMode))",
            "\(wordZText("单位", "Unit", mode: languageMode)): \(rawResult.request.unit.title(in: languageMode))",
            "\(wordZText("上下文", "Context", mode: languageMode)): \(rawResult.request.contextBasis.title(in: languageMode))",
            "\(wordZText("后端", "Backend", mode: languageMode)): \(rawResult.backendKind.title(in: languageMode))",
            "\(wordZText("后端版本", "Backend Revision", mode: languageMode)): \(rawResult.backendRevision)",
            "\(wordZText("资源版本", "Resource Revision", mode: languageMode)): \(rawResult.resourceRevision)",
            "\(wordZText("规则包", "Domain Pack", mode: languageMode)): \(rawResult.request.domainPackSummary(in: languageMode))",
            "\(wordZText("规则配置", "Rule Profile", mode: languageMode)): \(rawResult.request.ruleProfile.title)",
            "\(wordZText("校准版本", "Calibration Revision", mode: languageMode)): \(rawResult.calibrationProfileRevision)",
            "\(wordZText("阈值预设", "Threshold Preset", mode: languageMode)): \(thresholdPreset.title(in: languageMode))",
            "\(wordZText("决策阈值", "Decision Threshold", mode: languageMode)): \(format(rawResult.request.thresholds.decisionThreshold))",
            "\(wordZText("最小证据", "Minimum Evidence", mode: languageMode)): \(format(rawResult.request.thresholds.minimumEvidence))",
            "\(wordZText("中性偏置", "Neutral Bias", mode: languageMode)): \(format(rawResult.request.thresholds.neutralBias))",
            "\(wordZText("已审校样本", "Reviewed Samples", mode: languageMode)): \(presentationResult.reviewSummary.reviewedCount)",
            "\(wordZText("人工改标", "Overrides", mode: languageMode)): \(presentationResult.reviewSummary.overriddenCount)",
            "\(wordZText("确认原判", "Confirmed Raw", mode: languageMode)): \(presentationResult.reviewSummary.confirmedRawCount)"
        ]

        if !rawResult.lexiconVersion.isEmpty {
            lines.append("Lexicon: \(rawResult.lexiconVersion)")
        }
        if !rawResult.activePackIDs.isEmpty {
            lines.append(
                "\(wordZText("激活规则包", "Active Packs", mode: languageMode)): \(rawResult.activePackIDs.map { $0.title(in: languageMode) }.joined(separator: ", "))"
            )
        }
        if !rawResult.userLexiconBundleIDs.isEmpty {
            lines.append(
                "\(wordZText("用户词典", "User Lexicon Bundles", mode: languageMode)): \(rawResult.userLexiconBundleIDs.joined(separator: ", "))"
            )
        }

        lines.append(contentsOf: additionalMetadataLines)

        lines.append(
            "\(wordZText("总体", "Overall", mode: languageMode)): +\(presentationResult.effectiveOverallSummary.positiveCount) / =\(presentationResult.effectiveOverallSummary.neutralCount) / -\(presentationResult.effectiveOverallSummary.negativeCount)"
        )
        for group in presentationResult.effectiveGroupSummaries {
            lines.append("\(group.title): +\(group.positiveCount) / =\(group.neutralCount) / -\(group.negativeCount)")
        }
        return lines
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: SentimentPageSize,
        languageMode: AppLanguageMode
    ) -> ResultPaginationSceneModel {
        guard totalRows > 0 else {
            return ResultPaginationSceneModel(
                currentPage: 1,
                totalPages: 1,
                pageSizeLabel: pageSize.title(in: languageMode),
                rangeLabel: "0 / 0",
                canGoBackward: false,
                canGoForward: false
            )
        }

        let totalPages: Int
        if let rowLimit = pageSize.rowLimit {
            totalPages = max(1, Int(ceil(Double(totalRows) / Double(rowLimit))))
        } else {
            totalPages = 1
        }
        let safePage = min(max(currentPage, 1), totalPages)
        let rangeLabel: String
        if let rowLimit = pageSize.rowLimit {
            let start = ((safePage - 1) * rowLimit) + 1
            let end = min(safePage * rowLimit, totalRows)
            rangeLabel = "\(start)-\(end) / \(totalRows)"
        } else {
            rangeLabel = "1-\(totalRows) / \(totalRows)"
        }

        return ResultPaginationSceneModel(
            currentPage: safePage,
            totalPages: totalPages,
            pageSizeLabel: pageSize.title(in: languageMode),
            rangeLabel: rangeLabel,
            canGoBackward: safePage > 1,
            canGoForward: safePage < totalPages
        )
    }

    private func sliceRows(
        _ rows: [SentimentEffectiveRow],
        currentPage: Int,
        pageSize: SentimentPageSize
    ) -> ArraySlice<SentimentEffectiveRow> {
        guard let rowLimit = pageSize.rowLimit else {
            return rows[rows.startIndex..<rows.endIndex]
        }
        let startIndex = max(0, (currentPage - 1) * rowLimit)
        guard startIndex < rows.count else {
            return rows[rows.endIndex..<rows.endIndex]
        }
        let endIndex = min(startIndex + rowLimit, rows.count)
        return rows[startIndex..<endIndex]
    }

    private func presentation(for key: SentimentColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .source, .finalLabel, .rawLabel, .reviewStatus:
            return .label
        case .text, .evidence:
            return .summary
        case .positivity, .neutrality, .negativity, .netScore:
            return .numeric(precision: 4)
        }
    }

    private func widthPolicy(for key: SentimentColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .source, .finalLabel, .rawLabel, .reviewStatus:
            return .standard
        case .text, .evidence:
            return .summary
        case .positivity, .neutrality, .negativity, .netScore:
            return .numeric
        }
    }

    private func sortDirection(for key: SentimentColumnKey, mode: SentimentSortMode) -> NativeTableSortDirection? {
        switch (key, mode) {
        case (.positivity, .positivityDescending),
             (.neutrality, .neutralityDescending),
             (.negativity, .negativityDescending),
             (.netScore, .netScoreDescending):
            return .descending
        case (.finalLabel, .labelAscending),
             (.reviewStatus, .reviewStatusAscending),
             (.source, .sourceAscending):
            return .ascending
        default:
            return nil
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
