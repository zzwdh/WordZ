import Foundation

struct CollocateSceneBuilder {
    func build(
        from result: CollocateResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        focusMetric: CollocateAssociationMetric,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        sortMode: CollocateSortMode,
        pageSize: CollocatePageSize,
        currentPage: Int,
        visibleColumns: Set<CollocateColumnKey>,
        languageMode: AppLanguageMode = .system
    ) -> CollocateSceneModel {
        let filteredRows = filterRows(from: result.rows, stopwordFilter: stopwordFilter)
        let sortedRows = sortRows(filteredRows, mode: sortMode)
        return build(
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            focusMetric: focusMetric,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            languageMode: languageMode,
            filteredRows: filteredRows,
            sortedRows: sortedRows
        )
    }

    func build(
        from result: CollocateResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        focusMetric: CollocateAssociationMetric,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        sortMode: CollocateSortMode,
        pageSize: CollocatePageSize,
        currentPage: Int,
        visibleColumns: Set<CollocateColumnKey>,
        languageMode: AppLanguageMode = .system,
        filteredRows: [CollocateRow],
        sortedRows: [CollocateRow]
    ) -> CollocateSceneModel {
        let pagination = buildPagination(totalRows: sortedRows.count, currentPage: currentPage, pageSize: pageSize, languageMode: languageMode)
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)
        let pageOffset = pagination.currentPage == 1 || pageSize.rowLimit == nil
            ? 0
            : (pagination.currentPage - 1) * (pageSize.rowLimit ?? 0)

        let visibleSceneRows = pageRows.enumerated().map { index, row in
            CollocateSceneRow(
                id: row.id,
                rankText: "\(pageOffset + index + 1)",
                word: row.word,
                totalText: "\(row.total)",
                leftText: "\(row.left)",
                rightText: "\(row.right)",
                wordFreqText: "\(row.wordFreq)",
                keywordFreqText: "\(row.keywordFreq)",
                rateText: String(format: "%.4f", row.rate),
                logDiceText: String(format: "%.2f", row.logDice),
                mutualInformationText: String(format: "%.2f", row.mutualInformation),
                tScoreText: String(format: "%.2f", row.tScore)
            )
        }
        let tableRows = visibleSceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    CollocateColumnKey.rank.rawValue: row.rankText,
                    CollocateColumnKey.word.rawValue: row.word,
                    CollocateColumnKey.total.rawValue: row.totalText,
                    CollocateColumnKey.left.rawValue: row.leftText,
                    CollocateColumnKey.right.rawValue: row.rightText,
                    CollocateColumnKey.wordFreq.rawValue: row.wordFreqText,
                    CollocateColumnKey.keywordFreq.rawValue: row.keywordFreqText,
                    CollocateColumnKey.rate.rawValue: row.rateText,
                    CollocateColumnKey.logDice.rawValue: row.logDiceText,
                    CollocateColumnKey.mutualInformation.rawValue: row.mutualInformationText,
                    CollocateColumnKey.tScore.rawValue: row.tScoreText
                ]
            )
        }

        let methodNotes = [
            focusMetric.summary(in: languageMode),
            wordZText(
                "建议先看 LogDice 或 T-Score，再结合原始频次判断是否稳定可靠。",
                "A good workflow is to inspect LogDice or T-Score first, then confirm stability with raw frequency.",
                mode: languageMode
            ),
            wordZText(
                "MI 更适合找专属性强的低频搭配，但不宜单独作为最终结论。",
                "MI is useful for highly exclusive low-frequency pairs, but it should not be used alone as the final criterion.",
                mode: languageMode
            )
        ]

        let exportMetadataLines = AnalysisExportMetadataSupport.notes(
            analysisTitle: wordZText("搭配词", "Collocates", mode: languageMode),
            languageMode: languageMode,
            visibleRows: visibleSceneRows.count,
            totalRows: sortedRows.count,
            query: query,
            queryLabel: wordZText("节点词", "Keyword", mode: languageMode),
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            additionalLines: [
                "\(wordZText("左窗口", "Left Window", mode: languageMode)): \(leftWindow)",
                "\(wordZText("右窗口", "Right Window", mode: languageMode)): \(rightWindow)",
                "\(wordZText("最小频次", "Minimum Frequency", mode: languageMode)): \(minFreq)",
                "\(wordZText("重点指标", "Focus Metric", mode: languageMode)): \(focusMetric.title(in: languageMode))",
                "\(wordZText("排序方式", "Sort Order", mode: languageMode)): \(sortMode.title(in: languageMode))"
            ]
        )

        return CollocateSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            focusMetric: focusMetric,
            focusMetricSummary: focusMetric.summary(in: languageMode),
            methodNotes: methodNotes,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            sorting: CollocateSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "collocate",
                columns: CollocateColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .rank || key == .word
                    )
                },
                defaultDensity: .compact
            ),
            totalRows: result.rows.count,
            filteredRows: filteredRows.count,
            visibleRows: visibleSceneRows.count,
            rows: visibleSceneRows,
            tableRows: tableRows,
            exportMetadataLines: exportMetadataLines,
            searchError: ""
        )
    }

    func filterRows(from rows: [CollocateRow], stopwordFilter: StopwordFilterState) -> [CollocateRow] {
        SearchFilterSupport.filterWordLikeRows(
            rows,
            query: "",
            options: .default,
            stopword: stopwordFilter,
            text: \.word
        ).rows
    }

    private func presentation(for key: CollocateColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .word:
            return .keyword
        case .rate:
            return .numeric(precision: 4)
        case .logDice, .mutualInformation, .tScore:
            return .numeric(precision: 2)
        default:
            return .numeric(precision: 0)
        }
    }

    private func widthPolicy(for key: CollocateColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .word:
            return .keyword
        default:
            return .numeric
        }
    }

    func sortRows(_ rows: [CollocateRow], mode: CollocateSortMode) -> [CollocateRow] {
        switch mode {
        case .frequencyDescending:
            return rows.sorted {
                if $0.total == $1.total {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.total > $1.total
            }
        case .frequencyAscending:
            return rows.sorted {
                if $0.total == $1.total {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.total < $1.total
            }
        case .alphabeticalAscending:
            return rows.sorted {
                $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
            }
        case .rateDescending:
            return rows.sorted {
                if $0.rate == $1.rate {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.rate > $1.rate
            }
        case .logDiceDescending:
            return rows.sorted {
                if $0.logDice == $1.logDice {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.logDice > $1.logDice
            }
        case .mutualInformationDescending:
            return rows.sorted {
                if $0.mutualInformation == $1.mutualInformation {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.mutualInformation > $1.mutualInformation
            }
        case .tScoreDescending:
            return rows.sorted {
                if $0.tScore == $1.tScore {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.tScore > $1.tScore
            }
        }
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: CollocatePageSize,
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
        _ rows: [CollocateRow],
        currentPage: Int,
        pageSize: CollocatePageSize
    ) -> ArraySlice<CollocateRow> {
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

    private func sortIndicator(for key: CollocateColumnKey, sortMode: CollocateSortMode) -> String? {
        switch (key, sortMode) {
        case (.word, .alphabeticalAscending),
             (.total, .frequencyAscending):
            return "↑"
        case (.total, .frequencyDescending),
             (.rate, .rateDescending),
             (.logDice, .logDiceDescending),
             (.mutualInformation, .mutualInformationDescending),
             (.tScore, .tScoreDescending):
            return "↓"
        default:
            return nil
        }
    }
}
