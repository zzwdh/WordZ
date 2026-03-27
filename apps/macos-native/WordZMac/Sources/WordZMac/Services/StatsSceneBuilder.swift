import Foundation

struct StatsSceneBuilder {
    @MainActor
    func build(
        from result: StatsResult,
        sortMode: StatsSortMode,
        pageSize: StatsPageSize,
        currentPage: Int,
        visibleColumns: Set<StatsColumnKey>
    ) -> StatsSceneModel {
        let languageMode = WordZLocalization.shared.effectiveMode
        let metrics = [
            StatsMetricSceneItem(id: "token", title: wordZText("Token", "Token", mode: languageMode), value: "\(result.tokenCount)"),
            StatsMetricSceneItem(id: "type", title: wordZText("Type", "Type", mode: languageMode), value: "\(result.typeCount)"),
            StatsMetricSceneItem(id: "ttr", title: "TTR", value: String(format: "%.4f", result.ttr)),
            StatsMetricSceneItem(id: "sttr", title: "STTR", value: String(format: "%.4f", result.sttr))
        ]

        let sortedRows = sortRows(result.frequencyRows, mode: sortMode)
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
                word: row.word,
                countText: "\(row.count)"
            )
        }
        let tableRows = visibleRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    StatsColumnKey.word.rawValue: row.word,
                    StatsColumnKey.count.rawValue: row.countText
                ]
            )
        }

        return StatsSceneModel(
            metrics: metrics,
            rows: visibleRows,
            tableRows: tableRows,
            sorting: StatsSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "stats",
                columns: StatsColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode)
                    )
                }
            ),
            totalRows: sortedRows.count,
            visibleRows: visibleRows.count
        )
    }

    private func sortIndicator(for key: StatsColumnKey, sortMode: StatsSortMode) -> String? {
        switch (key, sortMode) {
        case (.word, .alphabeticalAscending):
            return "↑"
        case (.word, .alphabeticalDescending):
            return "↓"
        case (.count, .frequencyAscending):
            return "↑"
        case (.count, .frequencyDescending):
            return "↓"
        default:
            return nil
        }
    }

    private func sortRows(_ rows: [FrequencyRow], mode: StatsSortMode) -> [FrequencyRow] {
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
