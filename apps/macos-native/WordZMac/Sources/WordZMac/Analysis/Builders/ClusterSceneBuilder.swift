import Foundation

struct ClusterSceneBuilder {
    func build(
        from result: ClusterResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        selectedN: Int,
        minimumFrequency: Int,
        sortMode: ClusterSortMode,
        pageSize: ClusterPageSize,
        currentPage: Int,
        visibleColumns: Set<ClusterColumnKey>,
        selectedRowID: String?,
        caseSensitive: Bool,
        punctuationMode: ClusterPunctuationMode,
        languageMode: AppLanguageMode = .system
    ) -> ClusterSceneModel {
        let filtered = filterRows(
            from: result,
            query: query,
            searchOptions: searchOptions,
            selectedN: selectedN,
            minimumFrequency: minimumFrequency
        )
        let sortedRows = sortRows(filtered.rows, mode: sortMode)
        return build(
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            selectedN: selectedN,
            minimumFrequency: minimumFrequency,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            selectedRowID: selectedRowID,
            caseSensitive: caseSensitive,
            punctuationMode: punctuationMode,
            languageMode: languageMode,
            filteredRows: filtered.rows,
            sortedRows: sortedRows,
            searchError: filtered.error
        )
    }

    func build(
        from result: ClusterResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        selectedN: Int,
        minimumFrequency: Int,
        sortMode: ClusterSortMode,
        pageSize: ClusterPageSize,
        currentPage: Int,
        visibleColumns: Set<ClusterColumnKey>,
        selectedRowID: String?,
        caseSensitive: Bool,
        punctuationMode: ClusterPunctuationMode,
        languageMode: AppLanguageMode = .system,
        filteredRows: [ClusterRow],
        sortedRows: [ClusterRow],
        searchError: String
    ) -> ClusterSceneModel {
        let pagination = buildPagination(totalRows: sortedRows.count, currentPage: currentPage, pageSize: pageSize, languageMode: languageMode)
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)
        let pageOffset = pagination.currentPage == 1 || pageSize.rowLimit == nil
            ? 0
            : (pagination.currentPage - 1) * (pageSize.rowLimit ?? 0)
        let rows = pageRows.enumerated().map { index, row in
            ClusterSceneRow(
                id: row.id,
                phrase: row.phrase,
                n: row.n,
                frequency: row.frequency,
                normalizedFrequency: row.normalizedFrequency,
                range: row.range,
                rangePercentage: row.rangePercentage,
                referenceFrequency: row.referenceFrequency,
                referenceNormalizedFrequency: row.referenceNormalizedFrequency,
                referenceRange: row.referenceRange,
                logRatio: row.logRatio
            )
        }
        let tableRows = rows.enumerated().map { index, row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    ClusterColumnKey.rank.rawValue: "\(pageOffset + index + 1)",
                    ClusterColumnKey.phrase.rawValue: row.phrase,
                    ClusterColumnKey.n.rawValue: "\(row.n)",
                    ClusterColumnKey.frequency.rawValue: "\(row.frequency)",
                    ClusterColumnKey.normalizedFrequency.rawValue: format(row.normalizedFrequency),
                    ClusterColumnKey.range.rawValue: "\(row.range)",
                    ClusterColumnKey.rangePercentage.rawValue: format(row.rangePercentage),
                    ClusterColumnKey.referenceFrequency.rawValue: row.referenceFrequency.map(String.init) ?? "",
                    ClusterColumnKey.referenceNormalizedFrequency.rawValue: row.referenceNormalizedFrequency.map(format) ?? "",
                    ClusterColumnKey.referenceRange.rawValue: row.referenceRange.map(String.init) ?? "",
                    ClusterColumnKey.logRatio.rawValue: row.logRatio.map(format) ?? ""
                ]
            )
        }
        let exportMetadataLines = [
            "\(wordZText("模式", "Mode", mode: languageMode)): \(result.mode.title(in: languageMode))",
            "N: \(selectedN)",
            "\(wordZText("最小频次", "Minimum Frequency", mode: languageMode)): \(minimumFrequency)",
            "\(wordZText("排序", "Sort", mode: languageMode)): \(sortMode.title(in: languageMode))",
            "\(wordZText("区分大小写", "Case Sensitive", mode: languageMode)): \(caseSensitive ? wordZText("是", "Yes", mode: languageMode) : wordZText("否", "No", mode: languageMode))",
            "\(wordZText("标点处理", "Punctuation", mode: languageMode)): \(punctuationMode.title(in: languageMode))",
            "\(wordZText("停用词", "Stopwords", mode: languageMode)): \(stopwordFilter.summaryText(in: languageMode))"
        ]

        return ClusterSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            mode: result.mode,
            selectedN: selectedN,
            minimumFrequency: minimumFrequency,
            caseSensitive: caseSensitive,
            punctuationMode: punctuationMode,
            sorting: ClusterSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            totalRows: result.rows.count,
            visibleRows: rows.count,
            filteredRows: filteredRows.count,
            selectedRowID: selectedRowID,
            rows: rows,
            table: NativeTableDescriptor(
                storageKey: "cluster",
                columns: ClusterColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .rank || key == .phrase
                    )
                },
                defaultDensity: .compact
            ),
            tableRows: tableRows,
            exportMetadataLines: exportMetadataLines,
            searchError: searchError
        )
    }

    func filterRows(
        from result: ClusterResult,
        query: String,
        searchOptions: SearchOptionsState,
        selectedN: Int,
        minimumFrequency: Int
    ) -> (rows: [ClusterRow], error: String) {
        let matcher = SearchTextMatcher(query: query, options: searchOptions)
        guard matcher.error.isEmpty else {
            return ([], matcher.error)
        }
        let rows = result.rows.filter { row in
            row.n == selectedN &&
                row.frequency >= minimumFrequency &&
                matcher.matches(row.phrase)
        }
        return (rows, "")
    }

    func sortRows(_ rows: [ClusterRow], mode: ClusterSortMode) -> [ClusterRow] {
        switch mode {
        case .frequencyDescending:
            return rows.sorted {
                if $0.frequency == $1.frequency {
                    return $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
                }
                return $0.frequency > $1.frequency
            }
        case .alphabeticalAscending:
            return rows.sorted {
                $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
            }
        }
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: ClusterPageSize,
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
        _ rows: [ClusterRow],
        currentPage: Int,
        pageSize: ClusterPageSize
    ) -> ArraySlice<ClusterRow> {
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

    private func presentation(for key: ClusterColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .phrase:
            return .keyword
        case .rank, .n, .frequency, .range, .referenceFrequency, .referenceRange:
            return .numeric(precision: 0)
        case .normalizedFrequency, .rangePercentage, .referenceNormalizedFrequency, .logRatio:
            return .numeric(precision: 4)
        }
    }

    private func widthPolicy(for key: ClusterColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .phrase:
            return .keyword
        case .rank, .n, .frequency, .range, .referenceFrequency, .referenceRange:
            return .numeric
        case .normalizedFrequency, .rangePercentage, .referenceNormalizedFrequency, .logRatio:
            return .numeric
        }
    }

    private func sortIndicator(for key: ClusterColumnKey, sortMode: ClusterSortMode) -> String? {
        switch (key, sortMode) {
        case (.phrase, .alphabeticalAscending), (.frequency, .frequencyDescending):
            return "↓"
        default:
            return nil
        }
    }

    private func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
