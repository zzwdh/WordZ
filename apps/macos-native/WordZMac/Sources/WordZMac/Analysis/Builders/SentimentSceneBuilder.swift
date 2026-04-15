import Foundation

struct SentimentSceneBuilder {
    func build(
        from result: SentimentRunResult,
        thresholdPreset: SentimentThresholdPreset,
        filterQuery: String,
        labelFilter: SentimentLabel?,
        sortMode: SentimentSortMode,
        pageSize: SentimentPageSize,
        currentPage: Int,
        visibleColumns: Set<SentimentColumnKey>,
        selectedRowID: String?,
        chartKind: SentimentChartKind,
        languageMode: AppLanguageMode = .system
    ) -> SentimentSceneModel {
        let filteredRows = filterRows(
            result.rows,
            query: filterQuery,
            labelFilter: labelFilter
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
                values: [
                    SentimentColumnKey.source.rawValue: row.groupTitle.isEmpty ? row.sourceTitle : "\(row.groupTitle) · \(row.sourceTitle)",
                    SentimentColumnKey.text.rawValue: row.text,
                    SentimentColumnKey.positivity.rawValue: formatPercent(row.positivityScore),
                    SentimentColumnKey.neutrality.rawValue: formatPercent(row.neutralityScore),
                    SentimentColumnKey.negativity.rawValue: formatPercent(row.negativityScore),
                    SentimentColumnKey.finalLabel.rawValue: row.finalLabel.title(in: languageMode),
                    SentimentColumnKey.netScore.rawValue: format(row.netScore),
                    SentimentColumnKey.evidence.rawValue: row.evidencePreview
                ]
            )
        }

        let filteredSceneRows = sortedRows.map(makeSceneRow)
        let positiveExamples = filteredSceneRows.filter { $0.finalLabel == .positive }.prefix(5)
        let neutralExamples = filteredSceneRows.filter { $0.finalLabel == .neutral }.prefix(5)
        let negativeExamples = filteredSceneRows.filter { $0.finalLabel == .negative }.prefix(5)
        let exportMetadataLines = buildMetadataLines(
            result: result,
            thresholdPreset: thresholdPreset,
            languageMode: languageMode
        )

        return SentimentSceneModel(
            source: result.request.source,
            unit: result.request.unit,
            contextBasis: result.request.contextBasis,
            backend: result.backendKind,
            backendRevision: result.backendRevision,
            resourceRevision: result.resourceRevision,
            supportsEvidenceHits: result.supportsEvidenceHits,
            thresholdPreset: thresholdPreset,
            thresholds: result.request.thresholds,
            chartKind: chartKind,
            filterQuery: filterQuery,
            labelFilter: labelFilter,
            summary: result.overallSummary,
            groupSummaries: result.groupSummaries,
            sorting: SentimentSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            totalRows: result.rows.count,
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
                    count: result.overallSummary.positiveCount,
                    ratio: result.overallSummary.positiveRatio
                ),
                SentimentChartSegment(
                    label: .neutral,
                    count: result.overallSummary.neutralCount,
                    ratio: result.overallSummary.neutralRatio
                ),
                SentimentChartSegment(
                    label: .negative,
                    count: result.overallSummary.negativeCount,
                    ratio: result.overallSummary.negativeRatio
                )
            ],
            trendPoints: Array(result.rows.prefix(60).enumerated().map { offset, row in
                SentimentTrendPoint(
                    index: offset + 1,
                    label: row.finalLabel,
                    netScore: row.netScore,
                    title: row.sourceTitle
                )
            }),
            table: NativeTableDescriptor(
                storageKey: "sentiment",
                columns: SentimentColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, mode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .source || key == .text
                    )
                },
                defaultDensity: .reading
            ),
            tableRows: tableRows,
            exportMetadataLines: exportMetadataLines
        )
    }

    private func filterRows(
        _ rows: [SentimentRowResult],
        query: String,
        labelFilter: SentimentLabel?
    ) -> [SentimentRowResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return rows.filter { row in
            let matchesLabel = labelFilter.map { row.finalLabel == $0 } ?? true
            let matchesQuery: Bool
            if trimmedQuery.isEmpty {
                matchesQuery = true
            } else {
                let haystacks = [
                    row.text,
                    row.sourceTitle,
                    row.groupTitle ?? "",
                    row.evidence.map(\.surface).joined(separator: " "),
                    row.diagnostics.ruleSummary ?? "",
                    row.diagnostics.scopeNotes.joined(separator: " ")
                ].map { $0.localizedLowercase }
                matchesQuery = haystacks.contains { $0.contains(trimmedQuery.localizedLowercase) }
            }
            return matchesLabel && matchesQuery
        }
    }

    private func sortRows(_ rows: [SentimentRowResult], mode: SentimentSortMode) -> [SentimentRowResult] {
        switch mode {
        case .original:
            return rows
        case .positivityDescending:
            return rows.sorted { compare($0, $1, value: \.positivityScore, descending: true) }
        case .neutralityDescending:
            return rows.sorted { compare($0, $1, value: \.neutralityScore, descending: true) }
        case .negativityDescending:
            return rows.sorted { compare($0, $1, value: \.negativityScore, descending: true) }
        case .netScoreDescending:
            return rows.sorted { compare($0, $1, value: \.netScore, descending: true) }
        case .labelAscending:
            return rows.sorted {
                if $0.finalLabel.rawValue == $1.finalLabel.rawValue {
                    return $0.sourceTitle.localizedCaseInsensitiveCompare($1.sourceTitle) == .orderedAscending
                }
                return $0.finalLabel.rawValue < $1.finalLabel.rawValue
            }
        case .sourceAscending:
            return rows.sorted {
                let sourceCompare = $0.sourceTitle.localizedCaseInsensitiveCompare($1.sourceTitle)
                if sourceCompare == .orderedSame {
                    return $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending
                }
                return sourceCompare == .orderedAscending
            }
        }
    }

    private func compare(
        _ lhs: SentimentRowResult,
        _ rhs: SentimentRowResult,
        value: KeyPath<SentimentRowResult, Double>,
        descending: Bool
    ) -> Bool {
        let left = lhs[keyPath: value]
        let right = rhs[keyPath: value]
        if left == right {
            return lhs.text.localizedCaseInsensitiveCompare(rhs.text) == .orderedAscending
        }
        return descending ? left > right : left < right
    }

    private func makeSceneRow(_ row: SentimentRowResult) -> SentimentSceneRow {
        SentimentSceneRow(
            id: row.id,
            sourceTitle: row.sourceTitle,
            groupTitle: row.groupTitle ?? "",
            text: row.text,
            positivityScore: row.positivityScore,
            neutralityScore: row.neutralityScore,
            negativityScore: row.negativityScore,
            finalLabel: row.finalLabel,
            netScore: row.netScore,
            evidenceCount: row.evidenceCount,
            evidencePreview: evidencePreview(for: row),
            evidence: row.evidence,
            diagnostics: row.diagnostics,
            sentenceID: row.sentenceID,
            tokenIndex: row.tokenIndex
        )
    }

    private func evidencePreview(for row: SentimentRowResult) -> String {
        if !row.evidence.isEmpty {
            return row.evidence.prefix(3).map { hit in
                "\(hit.surface) (\(format(hit.adjustedScore)))"
            }.joined(separator: ", ")
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
        result: SentimentRunResult,
        thresholdPreset: SentimentThresholdPreset,
        languageMode: AppLanguageMode
    ) -> [String] {
        var lines = [
            "\(wordZText("来源", "Source", mode: languageMode)): \(result.request.source.title(in: languageMode))",
            "\(wordZText("单位", "Unit", mode: languageMode)): \(result.request.unit.title(in: languageMode))",
            "\(wordZText("上下文", "Context", mode: languageMode)): \(result.request.contextBasis.title(in: languageMode))",
            "\(wordZText("后端", "Backend", mode: languageMode)): \(result.backendKind.title(in: languageMode))",
            "\(wordZText("后端版本", "Backend Revision", mode: languageMode)): \(result.backendRevision)",
            "\(wordZText("资源版本", "Resource Revision", mode: languageMode)): \(result.resourceRevision)",
            "\(wordZText("阈值预设", "Threshold Preset", mode: languageMode)): \(thresholdPreset.title(in: languageMode))",
            "\(wordZText("决策阈值", "Decision Threshold", mode: languageMode)): \(format(result.request.thresholds.decisionThreshold))",
            "\(wordZText("最小证据", "Minimum Evidence", mode: languageMode)): \(format(result.request.thresholds.minimumEvidence))",
            "\(wordZText("中性偏置", "Neutral Bias", mode: languageMode)): \(format(result.request.thresholds.neutralBias))"
        ]

        if !result.lexiconVersion.isEmpty {
            lines.append("Lexicon: \(result.lexiconVersion)")
        }

        lines.append(
            "\(wordZText("总体", "Overall", mode: languageMode)): +\(result.overallSummary.positiveCount) / =\(result.overallSummary.neutralCount) / -\(result.overallSummary.negativeCount)"
        )
        for group in result.groupSummaries {
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
        _ rows: [SentimentRowResult],
        currentPage: Int,
        pageSize: SentimentPageSize
    ) -> ArraySlice<SentimentRowResult> {
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
        case .source, .finalLabel:
            return .label
        case .text, .evidence:
            return .summary
        case .positivity, .neutrality, .negativity, .netScore:
            return .numeric(precision: 4)
        }
    }

    private func widthPolicy(for key: SentimentColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .source, .finalLabel:
            return .standard
        case .text, .evidence:
            return .summary
        case .positivity, .neutrality, .negativity, .netScore:
            return .numeric
        }
    }

    private func sortIndicator(for key: SentimentColumnKey, mode: SentimentSortMode) -> String? {
        switch (key, mode) {
        case (.positivity, .positivityDescending),
             (.neutrality, .neutralityDescending),
             (.negativity, .negativityDescending),
             (.netScore, .netScoreDescending),
             (.finalLabel, .labelAscending),
             (.source, .sourceAscending):
            return "↓"
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
