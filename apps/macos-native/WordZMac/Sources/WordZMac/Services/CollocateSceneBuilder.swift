import Foundation

struct CollocateSceneBuilder {
    @MainActor
    func build(
        from result: CollocateResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        sortMode: CollocateSortMode,
        pageSize: CollocatePageSize,
        currentPage: Int,
        visibleColumns: Set<CollocateColumnKey>
    ) -> CollocateSceneModel {
        let languageMode = WordZLocalization.shared.effectiveMode
        let filtered = SearchFilterSupport.filterWordLikeRows(
            result.rows,
            query: "",
            options: .default,
            stopword: stopwordFilter,
            text: \.word
        )
        let sortedRows = sortRows(filtered.rows, mode: sortMode)
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
                rateText: String(format: "%.4f", row.rate)
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
                    CollocateColumnKey.rate.rawValue: row.rateText
                ]
            )
        }

        return CollocateSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
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
            filteredRows: sortedRows.count,
            visibleRows: visibleSceneRows.count,
            rows: visibleSceneRows,
            tableRows: tableRows,
            searchError: ""
        )
    }

    private func presentation(for key: CollocateColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .word:
            return .keyword
        case .rate:
            return .numeric(precision: 4)
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

    private func sortRows(_ rows: [CollocateRow], mode: CollocateSortMode) -> [CollocateRow] {
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
             (.rate, .rateDescending):
            return "↓"
        default:
            return nil
        }
    }
}
