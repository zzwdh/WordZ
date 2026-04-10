import Foundation

extension TopicsSceneBuilder {
    func presentation(for key: TopicsColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .paragraph:
            return .numeric(precision: 0)
        case .score:
            return .numeric(precision: 3)
        case .excerpt:
            return .summary
        }
    }

    func widthPolicy(for key: TopicsColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .paragraph:
            return .compact
        case .score:
            return .numeric
        case .excerpt:
            return .summary
        }
    }

    func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: TopicsPageSize,
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

    func sliceRows(
        _ rows: [TopicSegmentRow],
        currentPage: Int,
        pageSize: TopicsPageSize
    ) -> [TopicSegmentRow] {
        guard let rowLimit = pageSize.rowLimit else { return rows }
        let startIndex = max(0, (currentPage - 1) * rowLimit)
        guard startIndex < rows.count else { return [] }
        let endIndex = min(startIndex + rowLimit, rows.count)
        return Array(rows[startIndex..<endIndex])
    }

    func sortIndicator(for key: TopicsColumnKey, sortMode: TopicSegmentSortMode) -> String? {
        switch (key, sortMode) {
        case (.paragraph, .paragraphAscending):
            return "↑"
        case (.paragraph, .paragraphDescending):
            return "↓"
        case (.score, .relevanceAscending):
            return "↑"
        case (.score, .relevanceDescending):
            return "↓"
        case (.excerpt, .alphabeticalAscending):
            return "↑"
        case (.excerpt, .alphabeticalDescending):
            return "↓"
        default:
            return nil
        }
    }
}
