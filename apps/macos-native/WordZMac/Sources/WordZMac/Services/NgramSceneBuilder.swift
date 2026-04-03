import Foundation

struct NgramSceneBuilder {
    func build(
        from result: NgramResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        sortMode: NgramSortMode,
        pageSize: NgramPageSize,
        currentPage: Int,
        visibleColumns: Set<NgramColumnKey>,
        languageMode: AppLanguageMode = .system
    ) -> NgramSceneModel {
        let filtered = SearchFilterSupport.filterWordLikeRows(
            result.rows,
            query: query,
            options: searchOptions,
            stopword: stopwordFilter
        ) { $0.phrase }
        let filteredRows = filtered.rows
        let sortedRows = sortRows(filteredRows, mode: sortMode)
        let pagination = buildPagination(totalRows: sortedRows.count, currentPage: currentPage, pageSize: pageSize, languageMode: languageMode)
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)
        let pageOffset = pagination.currentPage == 1 || pageSize.rowLimit == nil
            ? 0
            : (pagination.currentPage - 1) * (pageSize.rowLimit ?? 0)

        let visibleSceneRows = pageRows.enumerated().map { index, row in
            NgramSceneRow(
                id: row.id,
                rankText: "\(pageOffset + index + 1)",
                phrase: row.phrase,
                countText: "\(row.count)"
            )
        }
        let tableRows = visibleSceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    NgramColumnKey.rank.rawValue: row.rankText,
                    NgramColumnKey.phrase.rawValue: row.phrase,
                    NgramColumnKey.count.rawValue: row.countText
                ]
            )
        }

        return NgramSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            n: result.n,
            sorting: NgramSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "ngram",
                columns: NgramColumnKey.allCases.map { key in
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
            totalRows: result.rows.count,
            visibleRows: visibleSceneRows.count,
            filteredRows: filteredRows.count,
            rows: visibleSceneRows,
            tableRows: tableRows,
            searchError: filtered.error
        )
    }

    private func presentation(for key: NgramColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .rank, .count:
            return .numeric(precision: 0)
        case .phrase:
            return .keyword
        }
    }

    private func widthPolicy(for key: NgramColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .rank, .count:
            return .numeric
        case .phrase:
            return .keyword
        }
    }

    private func sortRows(_ rows: [NgramRow], mode: NgramSortMode) -> [NgramRow] {
        switch mode {
        case .frequencyDescending:
            return rows.sorted {
                if $0.count == $1.count {
                    return $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
                }
                return $0.count > $1.count
            }
        case .frequencyAscending:
            return rows.sorted {
                if $0.count == $1.count {
                    return $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
                }
                return $0.count < $1.count
            }
        case .alphabeticalAscending:
            return rows.sorted {
                $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
            }
        case .alphabeticalDescending:
            return rows.sorted {
                $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedDescending
            }
        }
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: NgramPageSize,
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
        _ rows: [NgramRow],
        currentPage: Int,
        pageSize: NgramPageSize
    ) -> ArraySlice<NgramRow> {
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

    private func sortIndicator(for key: NgramColumnKey, sortMode: NgramSortMode) -> String? {
        switch (key, sortMode) {
        case (.phrase, .alphabeticalAscending), (.count, .frequencyAscending):
            return "↑"
        case (.phrase, .alphabeticalDescending), (.count, .frequencyDescending):
            return "↓"
        default:
            return nil
        }
    }
}
