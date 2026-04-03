import Foundation

struct KWICSceneBuilder {
    @MainActor
    func build(
        from result: KWICResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        leftWindow: Int,
        rightWindow: Int,
        sortMode: KWICSortMode,
        pageSize: KWICPageSize,
        currentPage: Int,
        visibleColumns: Set<KWICColumnKey>
    ) -> KWICSceneModel {
        let languageMode = WordZLocalization.shared.effectiveMode
        let filtered = SearchFilterSupport.filterWordLikeRows(
            result.rows,
            query: "",
            options: .default,
            stopword: stopwordFilter,
            text: \.node
        )
        let sortedRows = sortRows(filtered.rows, mode: sortMode)
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
            let leftContext = ConcordancePresentationSupport.normalizedContext(row.left)
            let keyword = ConcordancePresentationSupport.normalizedContext(row.node)
            let rightContext = ConcordancePresentationSupport.normalizedContext(row.right)
            return KWICSceneRow(
                id: row.id,
                leftContext: leftContext,
                keyword: keyword,
                rightContext: rightContext,
                concordanceText: ConcordancePresentationSupport.annotatedLine(
                    left: leftContext,
                    keyword: keyword,
                    right: rightContext
                ),
                citationText: ConcordancePresentationSupport.citationText(
                    sentenceNumber: row.sentenceId + 1,
                    keyword: keyword,
                    left: leftContext,
                    right: rightContext
                ),
                sentenceIndexText: "\(row.sentenceId + 1)",
                sentenceId: row.sentenceId,
                sentenceTokenIndex: row.sentenceTokenIndex
            )
        }
        let tableRows = visibleRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    KWICColumnKey.leftContext.rawValue: row.leftContext,
                    KWICColumnKey.keyword.rawValue: row.keyword,
                    KWICColumnKey.rightContext.rawValue: row.rightContext,
                    KWICColumnKey.sentenceIndex.rawValue: row.sentenceIndexText
                ]
            )
        }

        let exportMetadataLines = AnalysisExportMetadataSupport.notes(
            analysisTitle: "KWIC",
            languageMode: languageMode,
            visibleRows: visibleRows.count,
            totalRows: sortedRows.count,
            query: query,
            queryLabel: wordZText("节点词", "Keyword", mode: languageMode),
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            additionalLines: [
                "\(wordZText("左窗口", "Left Window", mode: languageMode)): \(leftWindow)",
                "\(wordZText("右窗口", "Right Window", mode: languageMode)): \(rightWindow)",
                "\(wordZText("排序方式", "Sort Order", mode: languageMode)): \(sortMode.title(in: languageMode))"
            ]
        )

        return KWICSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            sorting: KWICSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "kwic",
                columns: KWICColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .keyword
                    )
                },
                defaultDensity: .standard
            ),
            totalRows: result.rows.count,
            filteredRows: sortedRows.count,
            visibleRows: visibleRows.count,
            rows: visibleRows,
            tableRows: tableRows,
            exportMetadataLines: exportMetadataLines,
            searchError: ""
        )
    }

    private func presentation(for key: KWICColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .leftContext:
            return .contextLeading
        case .keyword:
            return .keyword
        case .rightContext:
            return .contextTrailing
        case .sentenceIndex:
            return .numeric(precision: 0)
        }
    }

    private func widthPolicy(for key: KWICColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .leftContext, .rightContext:
            return .context
        case .keyword:
            return .keyword
        case .sentenceIndex:
            return .compact
        }
    }

    private func sortIndicator(for key: KWICColumnKey, sortMode: KWICSortMode) -> String? {
        switch (key, sortMode) {
        case (.sentenceIndex, .sentenceAscending),
             (.leftContext, .leftContextAscending),
             (.keyword, .keywordAscending),
             (.rightContext, .rightContextAscending):
            return "↑"
        default:
            return nil
        }
    }

    private func sortRows(_ rows: [KWICRow], mode: KWICSortMode) -> [KWICRow] {
        switch mode {
        case .original:
            return rows
        case .sentenceAscending:
            return rows.sorted {
                if $0.sentenceId == $1.sentenceId {
                    return $0.id < $1.id
                }
                return $0.sentenceId < $1.sentenceId
            }
        case .leftContextAscending:
            return rows.sorted {
                compareLocalized($0.left, $1.left, fallback: $0.id < $1.id)
            }
        case .keywordAscending:
            return rows.sorted {
                compareLocalized($0.node, $1.node, fallback: $0.id < $1.id)
            }
        case .rightContextAscending:
            return rows.sorted {
                compareLocalized($0.right, $1.right, fallback: $0.id < $1.id)
            }
        }
    }

    private func compareLocalized(_ lhs: String, _ rhs: String, fallback: Bool) -> Bool {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        if comparison == .orderedSame {
            return fallback
        }
        return comparison == .orderedAscending
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: KWICPageSize,
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
        _ rows: [KWICRow],
        currentPage: Int,
        pageSize: KWICPageSize
    ) -> ArraySlice<KWICRow> {
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
