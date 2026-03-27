import Foundation

struct CompareSceneBuilder {
    @MainActor
    func build(
        selection: [CompareSelectableCorpusSceneItem],
        from result: CompareResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        sortMode: CompareSortMode,
        pageSize: ComparePageSize,
        currentPage: Int,
        visibleColumns: Set<CompareColumnKey>
    ) -> CompareSceneModel {
        let languageMode = WordZLocalization.shared.effectiveMode
        let filtered = SearchFilterSupport.filterWordLikeRows(
            result.rows,
            query: query,
            options: searchOptions,
            stopword: stopwordFilter
        ) { $0.word }
        let filteredRows = filtered.rows
        let sortedRows = sortRows(filteredRows, mode: sortMode)
        let pagination = buildPagination(totalRows: sortedRows.count, currentPage: currentPage, pageSize: pageSize, languageMode: languageMode)
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)

        let sceneRows = pageRows.map { row in
            CompareSceneRow(
                id: row.id,
                word: row.word,
                spreadText: "\(row.spread)",
                totalText: "\(row.total)",
                rangeText: String(format: "%.2f", row.range),
                dominantCorpus: row.dominantCorpusName,
                distributionText: row.perCorpus
                    .map { "\($0.corpusName) \($0.count)" }
                    .joined(separator: " · ")
            )
        }
        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    CompareColumnKey.word.rawValue: row.word,
                    CompareColumnKey.spread.rawValue: row.spreadText,
                    CompareColumnKey.total.rawValue: row.totalText,
                    CompareColumnKey.range.rawValue: row.rangeText,
                    CompareColumnKey.dominantCorpus.rawValue: row.dominantCorpus,
                    CompareColumnKey.distribution.rawValue: row.distributionText
                ]
            )
        }

        let summaries = result.corpora.map { corpus in
            CompareCorpusSummarySceneItem(
                id: corpus.id,
                title: corpus.corpusName,
                subtitle: corpus.folderName.isEmpty ? wordZText("未分类", "Unfiled", mode: languageMode) : corpus.folderName,
                tokenCountText: "\(corpus.tokenCount)",
                typeCountText: "\(corpus.typeCount)",
                ttrText: String(format: "%.4f", corpus.ttr),
                sttrText: String(format: "%.4f", corpus.sttr),
                topWordText: corpus.topWord.isEmpty ? "—" : "\(corpus.topWord) (\(corpus.topWordCount))"
            )
        }

        return CompareSceneModel(
            selection: selection,
            corpusSummaries: summaries,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            sorting: CompareSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "compare",
                columns: CompareColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode)
                    )
                }
            ),
            totalRows: result.rows.count,
            filteredRows: sortedRows.count,
            visibleRows: sceneRows.count,
            rows: sceneRows,
            tableRows: tableRows,
            searchError: filtered.error
        )
    }

    private func sortRows(_ rows: [CompareRow], mode: CompareSortMode) -> [CompareRow] {
        switch mode {
        case .spreadDescending:
            return rows.sorted {
                if $0.spread == $1.spread {
                    if $0.total == $1.total {
                        return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                    }
                    return $0.total > $1.total
                }
                return $0.spread > $1.spread
            }
        case .totalDescending:
            return rows.sorted {
                if $0.total == $1.total {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.total > $1.total
            }
        case .rangeDescending:
            return rows.sorted {
                if $0.range == $1.range {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.range > $1.range
            }
        case .alphabeticalAscending:
            return rows.sorted {
                $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
            }
        }
    }

    private func sortIndicator(for key: CompareColumnKey, sortMode: CompareSortMode) -> String? {
        switch (key, sortMode) {
        case (.word, .alphabeticalAscending):
            return "↑"
        case (.spread, .spreadDescending),
             (.total, .totalDescending),
             (.range, .rangeDescending):
            return "↓"
        default:
            return nil
        }
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: ComparePageSize,
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
        _ rows: [CompareRow],
        currentPage: Int,
        pageSize: ComparePageSize
    ) -> ArraySlice<CompareRow> {
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
