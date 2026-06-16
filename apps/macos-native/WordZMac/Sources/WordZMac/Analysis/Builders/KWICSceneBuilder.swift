import Foundation
import WordZExport
import WordZShared

struct KWICSceneBuilder {
    func build(
        from result: KWICResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        sourceFilterQuery: String = "",
        annotationState: WorkspaceAnnotationState = .default,
        leftWindow: Int,
        rightWindow: Int,
        sortMode: KWICSortMode,
        pageSize: KWICPageSize,
        currentPage: Int,
        visibleColumns: Set<KWICColumnKey>,
        languageMode: AppLanguageMode = .system
    ) -> KWICSceneModel {
        let filteredRows = filterRows(
            from: result.rows,
            stopwordFilter: stopwordFilter,
            sourceFilterQuery: sourceFilterQuery
        )
        let sortedRows = sortRows(filteredRows, mode: sortMode)
        return build(
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            sourceFilterQuery: sourceFilterQuery,
            annotationState: annotationState,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
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
        from result: KWICResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        sourceFilterQuery: String = "",
        annotationState: WorkspaceAnnotationState = .default,
        leftWindow: Int,
        rightWindow: Int,
        sortMode: KWICSortMode,
        pageSize: KWICPageSize,
        currentPage: Int,
        visibleColumns: Set<KWICColumnKey>,
        languageMode: AppLanguageMode = .system,
        filteredRows: [KWICRow],
        sortedRows: [KWICRow]
    ) -> KWICSceneModel {
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
        let firstVisibleRowNumber = firstRowNumber(
            currentPage: pagination.currentPage,
            pageSize: pageSize
        )
        let visibleRows = pageRows.enumerated().map { offset, row in
            let leftContext = ConcordancePresentationSupport.normalizedContext(row.left)
            let keyword = ConcordancePresentationSupport.normalizedContext(row.node)
            let rightContext = ConcordancePresentationSupport.normalizedContext(row.right)
            let sourceDisplayText = sourceDisplayText(for: row)
            let sourceMetadataText = metadataText(for: row, languageMode: languageMode)
            let displayedSentenceId = row.sourceSentenceId ?? row.sentenceId
            let baseCitation = ConcordancePresentationSupport.citationText(
                sentenceNumber: displayedSentenceId + 1,
                normalizedKeyword: keyword,
                normalizedLeft: leftContext,
                normalizedRight: rightContext
            )
            return KWICSceneRow(
                id: row.id,
                rowNumberText: "\(firstVisibleRowNumber + offset)",
                sourceID: row.sourceID,
                sourceTitle: row.sourceTitle,
                sourceFilePath: row.sourceFilePath,
                sourceFileName: row.sourceFileName,
                sourceType: row.sourceType,
                sourceIndex: row.sourceIndex,
                sourceMetadata: row.metadata,
                sourceDisplayText: sourceDisplayText,
                sourceMetadataText: sourceMetadataText,
                positionText: "\(displayedSentenceId + 1):\(row.sentenceTokenIndex + 1)",
                leftContext: leftContext,
                keyword: keyword,
                rightContext: rightContext,
                concordanceText: ConcordancePresentationSupport.annotatedLine(
                    normalizedLeft: leftContext,
                    normalizedKeyword: keyword,
                    normalizedRight: rightContext
                ),
                citationText: sourceDisplayText.isEmpty ? baseCitation : "\(sourceDisplayText) · \(baseCitation)",
                sentenceIndexText: "\(row.sentenceId + 1)",
                sentenceId: row.sentenceId,
                sourceSentenceId: row.sourceSentenceId,
                sentenceTokenIndex: row.sentenceTokenIndex
            )
        }
        let tableRows = visibleRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    KWICColumnKey.rowNumber.rawValue: row.rowNumberText,
                    KWICColumnKey.source.rawValue: row.sourceDisplayText,
                    KWICColumnKey.position.rawValue: row.positionText,
                    KWICColumnKey.leftContext.rawValue: row.leftContext,
                    KWICColumnKey.keyword.rawValue: row.keyword,
                    KWICColumnKey.rightContext.rawValue: row.rightContext,
                    KWICColumnKey.metadata.rawValue: row.sourceMetadataText,
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
                "\(wordZText("来源筛选", "Source Filter", mode: languageMode)): \(sourceFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines))",
                "\(wordZText("排序方式", "Sort Order", mode: languageMode)): \(sortMode.title(in: languageMode))",
                annotationState.summary(in: languageMode)
            ]
        )

        return KWICSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            sourceFilterQuery: sourceFilterQuery,
            annotationSummary: annotationState.summary(in: languageMode),
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
                        isPinned: false
                    )
                },
                defaultDensity: .standard
            ),
            totalRows: result.rows.count,
            filteredRows: sortedRows.count,
            visibleRows: visibleRows.count,
            rows: visibleRows,
            tableSnapshot: ResultTableSnapshot(rows: tableRows),
            exportMetadataLines: exportMetadataLines,
            searchError: ""
        )
    }

    func filterRows(
        from rows: [KWICRow],
        stopwordFilter: StopwordFilterState,
        sourceFilterQuery: String = ""
    ) -> [KWICRow] {
        let stopwordFilteredRows = SearchFilterSupport.filterWordLikeRows(
            rows,
            query: "",
            options: .default,
            stopword: stopwordFilter,
            text: \.node
        ).rows
        let terms = sourceFilterQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else { return stopwordFilteredRows }
        return stopwordFilteredRows.filter { row in
            let haystack = sourceSearchText(for: row).lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    private func presentation(for key: KWICColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .rowNumber:
            return .numeric(precision: 0)
        case .source:
            return .label
        case .position:
            return .contextCenter
        case .leftContext:
            return .contextLeading
        case .keyword:
            return .keyword
        case .rightContext:
            return .contextTrailing
        case .metadata:
            return .summary
        case .sentenceIndex:
            return .numeric(precision: 0)
        }
    }

    private func widthPolicy(for key: KWICColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .rowNumber, .position, .sentenceIndex:
            return .compact
        case .source:
            return .standard
        case .leftContext, .rightContext:
            return .context
        case .keyword:
            return .keyword
        case .metadata:
            return .summary
        }
    }

    private func sortIndicator(for key: KWICColumnKey, sortMode: KWICSortMode) -> String? {
        switch (key, sortMode) {
        case (.position, .sentenceAscending),
             (.sentenceIndex, .sentenceAscending),
             (.source, .sourceAscending),
             (.leftContext, .leftOneAscending),
             (.leftContext, .leftTwoAscending),
             (.leftContext, .leftThreeAscending),
             (.leftContext, .leftContextAscending),
             (.keyword, .keywordAscending),
             (.rightContext, .rightOneAscending),
             (.rightContext, .rightTwoAscending),
             (.rightContext, .rightThreeAscending),
             (.rightContext, .rightContextAscending),
             (.metadata, .metadataAscending):
            return "↑"
        default:
            return nil
        }
    }

    func sortRows(_ rows: [KWICRow], mode: KWICSortMode) -> [KWICRow] {
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
        case .leftOneAscending:
            return sortRowsByLeftToken(rows, offsetFromNode: 1)
        case .leftTwoAscending:
            return sortRowsByLeftToken(rows, offsetFromNode: 2)
        case .leftThreeAscending:
            return sortRowsByLeftToken(rows, offsetFromNode: 3)
        case .leftContextAscending:
            return rows.sorted {
                compareLocalized($0.left, $1.left, fallback: $0.id < $1.id)
            }
        case .keywordAscending:
            return rows.sorted {
                compareLocalized($0.node, $1.node, fallback: $0.id < $1.id)
            }
        case .rightOneAscending:
            return sortRowsByRightToken(rows, offsetFromNode: 1)
        case .rightTwoAscending:
            return sortRowsByRightToken(rows, offsetFromNode: 2)
        case .rightThreeAscending:
            return sortRowsByRightToken(rows, offsetFromNode: 3)
        case .rightContextAscending:
            return rows.sorted {
                compareLocalized($0.right, $1.right, fallback: $0.id < $1.id)
            }
        case .sourceAscending:
            return rows.sorted {
                compareLocalized(sourceDisplayText(for: $0), sourceDisplayText(for: $1), fallback: stableRowOrder($0, $1))
            }
        case .metadataAscending:
            return rows.sorted {
                compareLocalized(metadataText(for: $0, languageMode: .system), metadataText(for: $1, languageMode: .system), fallback: stableRowOrder($0, $1))
            }
        }
    }

    private func sourceDisplayText(for row: KWICRow) -> String {
        let title = row.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        let fileName = row.sourceFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fileName.isEmpty {
            return fileName
        }
        return row.sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func metadataText(for row: KWICRow, languageMode: AppLanguageMode) -> String {
        guard row.metadata.hasContent else { return "" }
        return row.metadata.compactSummary(in: languageMode)
    }

    private func sourceSearchText(for row: KWICRow) -> String {
        [
            row.sourceID,
            row.sourceTitle,
            row.sourceFilePath,
            row.sourceFileName,
            row.sourceType,
            row.metadata.sourceLabel,
            row.metadata.yearLabel,
            row.metadata.genreLabel,
            row.metadata.tagsText
        ].joined(separator: "\n")
    }

    private func sortRowsByLeftToken(_ rows: [KWICRow], offsetFromNode: Int) -> [KWICRow] {
        rows.sorted {
            let lhs = leftSortToken($0.left, offsetFromNode: offsetFromNode)
            let rhs = leftSortToken($1.left, offsetFromNode: offsetFromNode)
            return compareLocalized(lhs, rhs, fallback: stableRowOrder($0, $1))
        }
    }

    private func sortRowsByRightToken(_ rows: [KWICRow], offsetFromNode: Int) -> [KWICRow] {
        rows.sorted {
            let lhs = rightSortToken($0.right, offsetFromNode: offsetFromNode)
            let rhs = rightSortToken($1.right, offsetFromNode: offsetFromNode)
            return compareLocalized(lhs, rhs, fallback: stableRowOrder($0, $1))
        }
    }

    private func leftSortToken(_ context: String, offsetFromNode: Int) -> String {
        let tokens = contextTokens(context)
        guard tokens.count >= offsetFromNode else { return "" }
        return tokens[tokens.count - offsetFromNode]
    }

    private func rightSortToken(_ context: String, offsetFromNode: Int) -> String {
        let tokens = contextTokens(context)
        guard tokens.count >= offsetFromNode else { return "" }
        return tokens[offsetFromNode - 1]
    }

    private func contextTokens(_ context: String) -> [String] {
        context
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private func stableRowOrder(_ lhs: KWICRow, _ rhs: KWICRow) -> Bool {
        if lhs.sentenceId == rhs.sentenceId {
            if lhs.sentenceTokenIndex == rhs.sentenceTokenIndex {
                return lhs.id < rhs.id
            }
            return lhs.sentenceTokenIndex < rhs.sentenceTokenIndex
        }
        return lhs.sentenceId < rhs.sentenceId
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

    private func firstRowNumber(currentPage: Int, pageSize: KWICPageSize) -> Int {
        guard let rowLimit = pageSize.rowLimit else { return 1 }
        return max(1, ((currentPage - 1) * rowLimit) + 1)
    }
}
