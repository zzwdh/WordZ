import Foundation

struct WordSceneBuilder {
    func build(
        from result: StatsResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        definition: FrequencyMetricDefinition = .default,
        sortMode: WordSortMode,
        pageSize: WordPageSize,
        currentPage: Int,
        visibleColumns: Set<WordColumnKey>,
        languageMode: AppLanguageMode = .system,
        prefilteredDisplayableRows: [FrequencyRow]? = nil,
        filteredRows: [FrequencyRow]? = nil,
        filteredError: String? = nil,
        sortedRows: [FrequencyRow]? = nil
    ) -> WordSceneModel {
        let resolvedDisplayableRows = prefilteredDisplayableRows ?? displayableRows(from: result)
        let filtered = filteredRows.map { (rows: $0, error: filteredError ?? "") }
            ?? filterRows(
                from: resolvedDisplayableRows,
                query: query,
                searchOptions: searchOptions,
                stopwordFilter: stopwordFilter
            )
        let sortedRows = sortedRows ?? sortRows(filtered.rows, mode: sortMode, definition: definition)
        let pagination = buildPagination(totalRows: sortedRows.count, currentPage: currentPage, pageSize: pageSize, languageMode: languageMode)
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)
        let pageOffset = pagination.currentPage == 1 || pageSize.rowLimit == nil
            ? 0
            : (pagination.currentPage - 1) * (pageSize.rowLimit ?? 0)

        let sceneRows = pageRows.enumerated().map { offset, row in
            let displayRank = row.rank > 0 ? row.rank : pageOffset + offset + 1
            return WordSceneRow(
                id: row.id,
                rankText: "\(displayRank)",
                word: row.word,
                countText: "\(row.count)",
                normFrequencyText: String(format: "%.2f", FrequencyRowSupport.normalizedFrequency(for: row, tokenCount: result.tokenCount, definition: definition)),
                rangeText: "\(FrequencyRowSupport.rangeValue(for: row, definition: definition))",
                normRangeText: String(format: "%.2f", FrequencyRowSupport.normalizedRange(for: row, paragraphCount: result.paragraphCount, sentenceCount: result.sentenceCount, definition: definition))
            )
        }

        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    WordColumnKey.rank.rawValue: row.rankText,
                    WordColumnKey.word.rawValue: row.word,
                    WordColumnKey.count.rawValue: row.countText,
                    WordColumnKey.normFrequency.rawValue: row.normFrequencyText,
                    WordColumnKey.range.rawValue: row.rangeText,
                    WordColumnKey.normRange.rawValue: row.normRangeText
                ]
            )
        }
        let exportMetadataLines = AnalysisExportMetadataSupport.notes(
            analysisTitle: wordZText("词表", "Word List", mode: languageMode),
            languageMode: languageMode,
            visibleRows: sceneRows.count,
            totalRows: filtered.rows.count,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            additionalLines: [definition.summary(in: languageMode)]
        )

        return WordSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            definition: definition,
            definitionSummary: definition.summary(in: languageMode),
            exportMetadataLines: exportMetadataLines,
            sorting: WordSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "word",
                columns: WordColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: columnTitle(for: key, definition: definition, mode: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .rank || key == .word
                    )
                },
                defaultDensity: .compact
            ),
            totalRows: resolvedDisplayableRows.count,
            filteredRows: filtered.rows.count,
            visibleRows: sceneRows.count,
            rows: sceneRows,
            tableRows: tableRows,
            searchError: filtered.error
        )
    }

    private func presentation(for key: WordColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .word:
            return .keyword
        case .rank, .count, .range:
            return .numeric(precision: 0)
        case .normFrequency, .normRange:
            return .numeric(precision: 2)
        }
    }

    private func widthPolicy(for key: WordColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .word:
            return .keyword
        default:
            return .numeric
        }
    }

    func displayableRows(from result: StatsResult) -> [FrequencyRow] {
        FrequencyRowSupport.lexicalRows(from: result.frequencyRows)
    }

    func filterRows(
        from result: StatsResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState
    ) -> (rows: [FrequencyRow], error: String) {
        filterRows(
            from: displayableRows(from: result),
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter
        )
    }

    func filterRows(
        from rows: [FrequencyRow],
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState
    ) -> (rows: [FrequencyRow], error: String) {
        SearchFilterSupport.filterWordLikeRows(
            rows,
            query: query,
            options: searchOptions,
            stopword: stopwordFilter
        ) { $0.word }
    }

    func sortRows(_ rows: [FrequencyRow], mode: WordSortMode, definition: FrequencyMetricDefinition) -> [FrequencyRow] {
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

    private func columnTitle(
        for key: WordColumnKey,
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

    private func sortIndicator(for key: WordColumnKey, sortMode: WordSortMode) -> String? {
        switch (key, sortMode) {
        case (.rank, .rankAscending):
            return "↑"
        case (.rank, .rankDescending):
            return "↓"
        case (.word, .alphabeticalAscending), (.count, .frequencyAscending), (.normFrequency, .frequencyAscending):
            return "↑"
        case (.word, .alphabeticalDescending), (.count, .frequencyDescending), (.normFrequency, .frequencyDescending):
            return "↓"
        case (.range, .rangeAscending), (.normRange, .rangeAscending):
            return "↑"
        case (.range, .rangeDescending), (.normRange, .rangeDescending):
            return "↓"
        default:
            return nil
        }
    }

    private func buildPagination(totalRows: Int, currentPage: Int, pageSize: WordPageSize, languageMode: AppLanguageMode) -> ResultPaginationSceneModel {
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

        let totalPages = pageSize.rowLimit.map { max(1, Int(ceil(Double(totalRows) / Double($0)))) } ?? 1
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

    private func sliceRows(_ rows: [FrequencyRow], currentPage: Int, pageSize: WordPageSize) -> ArraySlice<FrequencyRow> {
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
