import Foundation

struct WordSceneBuilder {
    @MainActor
    func build(
        from result: StatsResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        sortMode: WordSortMode,
        pageSize: WordPageSize,
        currentPage: Int,
        visibleColumns: Set<WordColumnKey>
    ) -> WordSceneModel {
        let languageMode = WordZLocalization.shared.effectiveMode
        let filtered = SearchFilterSupport.filterWordLikeRows(
            result.frequencyRows,
            query: query,
            options: searchOptions,
            stopword: stopwordFilter
        ) { $0.word }
        let sortedRows = sortRows(filtered.rows, mode: sortMode)
        let pagination = buildPagination(totalRows: sortedRows.count, currentPage: currentPage, pageSize: pageSize, languageMode: languageMode)
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)
        let pageOffset = pagination.currentPage == 1 || pageSize.rowLimit == nil
            ? 0
            : (pagination.currentPage - 1) * (pageSize.rowLimit ?? 0)

        let sceneRows = pageRows.enumerated().map { index, row in
            WordSceneRow(
                id: row.id,
                rankText: "\(pageOffset + index + 1)",
                word: row.word,
                countText: "\(row.count)"
            )
        }

        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    WordColumnKey.rank.rawValue: row.rankText,
                    WordColumnKey.word.rawValue: row.word,
                    WordColumnKey.count.rawValue: row.countText
                ]
            )
        }

        return WordSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
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
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode)
                    )
                }
            ),
            totalRows: result.frequencyRows.count,
            filteredRows: filtered.rows.count,
            visibleRows: sceneRows.count,
            rows: sceneRows,
            tableRows: tableRows,
            searchError: filtered.error
        )
    }

    private func sortRows(_ rows: [FrequencyRow], mode: WordSortMode) -> [FrequencyRow] {
        switch mode {
        case .frequencyDescending:
            return rows.sorted {
                if $0.count == $1.count {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.count > $1.count
            }
        case .frequencyAscending:
            return rows.sorted {
                if $0.count == $1.count {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.count < $1.count
            }
        case .alphabeticalAscending:
            return rows.sorted {
                $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
            }
        case .alphabeticalDescending:
            return rows.sorted {
                $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedDescending
            }
        }
    }

    private func sortIndicator(for key: WordColumnKey, sortMode: WordSortMode) -> String? {
        switch (key, sortMode) {
        case (.word, .alphabeticalAscending), (.count, .frequencyAscending):
            return "↑"
        case (.word, .alphabeticalDescending), (.count, .frequencyDescending):
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
