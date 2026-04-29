import Foundation

struct StatsSceneBuilder {
    func build(
        from result: StatsResult,
        definition: FrequencyMetricDefinition = .default,
        sortMode: StatsSortMode,
        pageSize: StatsPageSize,
        currentPage: Int,
        visibleColumns: Set<StatsColumnKey>,
        languageMode: AppLanguageMode = .system,
        sortedRows: [FrequencyRow]? = nil
    ) -> StatsSceneModel {
        let metrics = [
            StatsMetricSceneItem(id: "token", title: wordZText("Token", "Token", mode: languageMode), value: "\(result.tokenCount)"),
            StatsMetricSceneItem(id: "type", title: wordZText("Type", "Type", mode: languageMode), value: "\(result.typeCount)"),
            StatsMetricSceneItem(id: "ttr", title: "TTR", value: String(format: "%.4f", result.ttr)),
            StatsMetricSceneItem(id: "sttr", title: "STTR", value: String(format: "%.4f", result.sttr)),
            StatsMetricSceneItem(id: "paragraph", title: wordZText("Paragraph", "Paragraph", mode: languageMode), value: "\(result.paragraphCount)")
        ]

        let sortedRows = sortedRows ?? self.sortedRows(
            from: result.frequencyRows,
            mode: sortMode,
            definition: definition
        )
        let pagination = buildPagination(
            totalRows: sortedRows.count,
            currentPage: currentPage,
            pageSize: pageSize,
            languageMode: languageMode
        )
        let pageRows = sliceRows(
            sortedRows,
            currentPage: pagination.currentPage,
            pageSize: pageSize
        )
        let visibleRows = pageRows.map { row in
            StatsFrequencySceneRow(
                id: row.id,
                rankText: "\(row.rank)",
                word: row.word,
                countText: "\(row.count)",
                normFrequencyText: String(format: "%.2f", FrequencyRowSupport.normalizedFrequency(for: row, tokenCount: result.tokenCount, definition: definition)),
                rangeText: "\(FrequencyRowSupport.rangeValue(for: row, definition: definition))",
                normRangeText: String(format: "%.2f", FrequencyRowSupport.normalizedRange(for: row, paragraphCount: result.paragraphCount, sentenceCount: result.sentenceCount, definition: definition))
            )
        }
        let tableRows = visibleRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                columnKey: StatsColumnKey.self
            ) {
                NativeTableCell(.rank, row.rankText)
                NativeTableCell(.word, row.word)
                NativeTableCell(.count, row.countText)
                NativeTableCell(.normFrequency, row.normFrequencyText)
                NativeTableCell(.range, row.rangeText)
                NativeTableCell(.normRange, row.normRangeText)
            }
        }
        let exportMetadataLines = AnalysisExportMetadataSupport.notes(
            analysisTitle: wordZText("词频统计", "Frequency Stats", mode: languageMode),
            languageMode: languageMode,
            visibleRows: visibleRows.count,
            totalRows: sortedRows.count,
            additionalLines: [definition.summary(in: languageMode)]
        )

        return StatsSceneModel(
            metrics: metrics,
            rows: visibleRows,
            tableRows: tableRows,
            tableSnapshot: ResultTableSnapshot.stable(rows: tableRows),
            definition: definition,
            definitionSummary: definition.summary(in: languageMode),
            exportMetadataLines: exportMetadataLines,
            sorting: StatsSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "stats",
                columnKey: StatsColumnKey.self,
                defaultDensity: .compact
            ) {
                for key in StatsColumnKey.allCases {
                    NativeTableColumnSpec(
                        key,
                        title: columnTitle(for: key, definition: definition, mode: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortDirection: sortDirection(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .rank || key == .word
                    )
                }
            },
            totalRows: sortedRows.count,
            visibleRows: visibleRows.count
        )
    }

    private func presentation(for key: StatsColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .word:
            return .keyword
        case .rank, .count, .range:
            return .numeric(precision: 0)
        case .normFrequency, .normRange:
            return .numeric(precision: 2)
        }
    }

    private func widthPolicy(for key: StatsColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .word:
            return .keyword
        default:
            return .numeric
        }
    }

    func sortedRows(
        from rows: [FrequencyRow],
        mode: StatsSortMode,
        definition: FrequencyMetricDefinition
    ) -> [FrequencyRow] {
        switch mode {
        case .frequencyDescending:
            return FrequencyRowSupport.sortRows(rows, criterion: .count, direction: .descending, definition: definition)
        case .frequencyAscending:
            return FrequencyRowSupport.sortRows(rows, criterion: .count, direction: .ascending, definition: definition)
        case .rankAscending:
            return FrequencyRowSupport.sortRows(rows, criterion: .rank, direction: .ascending, definition: definition)
        case .rankDescending:
            return FrequencyRowSupport.sortRows(rows, criterion: .rank, direction: .descending, definition: definition)
        case .rangeDescending:
            return FrequencyRowSupport.sortRows(rows, criterion: .range, direction: .descending, definition: definition)
        case .rangeAscending:
            return FrequencyRowSupport.sortRows(rows, criterion: .range, direction: .ascending, definition: definition)
        case .alphabeticalAscending:
            return FrequencyRowSupport.sortRows(rows, criterion: .word, direction: .ascending, definition: definition)
        case .alphabeticalDescending:
            return FrequencyRowSupport.sortRows(rows, criterion: .word, direction: .descending, definition: definition)
        }
    }

    private func sortDirection(for key: StatsColumnKey, sortMode: StatsSortMode) -> NativeTableSortDirection? {
        switch (key, sortMode) {
        case (.rank, .rankAscending):
            return .ascending
        case (.rank, .rankDescending):
            return .descending
        case (.word, .alphabeticalAscending):
            return .ascending
        case (.word, .alphabeticalDescending):
            return .descending
        case (.count, .frequencyAscending):
            return .ascending
        case (.count, .frequencyDescending):
            return .descending
        case (.normFrequency, .frequencyAscending):
            return .ascending
        case (.normFrequency, .frequencyDescending):
            return .descending
        case (.range, .rangeAscending):
            return .ascending
        case (.range, .rangeDescending):
            return .descending
        case (.normRange, .rangeAscending):
            return .ascending
        case (.normRange, .rangeDescending):
            return .descending
        default:
            return nil
        }
    }

    private func columnTitle(
        for key: StatsColumnKey,
        definition: FrequencyMetricDefinition,
        mode: AppLanguageMode
    ) -> String {
        switch key {
        case .normFrequency:
            return definition.normFrequencyTitle(in: mode)
        case .range:
            return definition.rangeTitle(in: mode)
        case .normRange:
            return definition.normRangeTitle(in: mode)
        default:
            return key.title(in: mode)
        }
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: StatsPageSize,
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
            let startIndex = ((safePage - 1) * rowLimit) + 1
            let endIndex = min(safePage * rowLimit, totalRows)
            rangeLabel = "\(startIndex)-\(endIndex) / \(totalRows)"
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
        _ rows: [FrequencyRow],
        currentPage: Int,
        pageSize: StatsPageSize
    ) -> ArraySlice<FrequencyRow> {
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
}
