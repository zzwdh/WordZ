import Foundation

struct LocatorSceneBuilder {
    @MainActor
    func build(
        from result: LocatorResult,
        source: LocatorSource,
        leftWindow: Int,
        rightWindow: Int,
        pageSize: LocatorPageSize,
        currentPage: Int,
        visibleColumns: Set<LocatorColumnKey>
    ) -> LocatorSceneModel {
        let languageMode = WordZLocalization.shared.effectiveMode
        let pagination = buildPagination(totalRows: result.rows.count, currentPage: currentPage, pageSize: pageSize, languageMode: languageMode)
        let pageRows = sliceRows(result.rows, currentPage: pagination.currentPage, pageSize: pageSize)
        let sceneRows = pageRows.map { row in
            LocatorSceneRow(
                id: row.id,
                sentenceId: row.sentenceId,
                sentenceIdText: "\(row.sentenceId + 1)",
                status: row.status,
                leftWords: row.leftWords,
                nodeWord: row.nodeWord,
                rightWords: row.rightWords,
                text: row.text,
                sourceCandidate: LocatorSource(
                    keyword: row.nodeWord.isEmpty ? source.keyword : row.nodeWord,
                    sentenceId: row.sentenceId,
                    nodeIndex: source.nodeIndex
                )
            )
        }
        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    LocatorColumnKey.sentenceId.rawValue: row.sentenceIdText,
                    LocatorColumnKey.status.rawValue: row.status,
                    LocatorColumnKey.leftWords.rawValue: row.leftWords,
                    LocatorColumnKey.nodeWord.rawValue: row.nodeWord,
                    LocatorColumnKey.rightWords.rawValue: row.rightWords,
                    LocatorColumnKey.text.rawValue: row.text
                ]
            )
        }

        return LocatorSceneModel(
            source: source,
            sentenceCount: result.sentenceCount,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            selectedPageSize: pageSize,
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "locator",
                columns: LocatorColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: nil
                    )
                }
            ),
            totalRows: result.rows.count,
            visibleRows: sceneRows.count,
            rows: sceneRows,
            tableRows: tableRows
        )
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: LocatorPageSize,
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
        _ rows: [LocatorRow],
        currentPage: Int,
        pageSize: LocatorPageSize
    ) -> ArraySlice<LocatorRow> {
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
