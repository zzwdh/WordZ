import Foundation

extension KeywordSceneBuilder {
    func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: KeywordPageSize,
        languageMode: AppLanguageMode
    ) -> KeywordPaginationContext {
        guard let pageLimit = pageSize.rowLimit, pageLimit > 0 else {
            let rangeLabel = totalRows == 0
                ? "0 / 0"
                : "1-\(totalRows) / \(totalRows)"
            return KeywordPaginationContext(
                globalStartIndex: 0,
                sceneModel: ResultPaginationSceneModel(
                    currentPage: 1,
                    totalPages: 1,
                    pageSizeLabel: pageSize.title(in: languageMode),
                    rangeLabel: rangeLabel,
                    canGoBackward: false,
                    canGoForward: false
                )
            )
        }

        guard totalRows > 0 else {
            return KeywordPaginationContext(
                globalStartIndex: 0,
                sceneModel: ResultPaginationSceneModel(
                    currentPage: 1,
                    totalPages: 1,
                    pageSizeLabel: pageSize.title(in: languageMode),
                    rangeLabel: "0 / 0",
                    canGoBackward: false,
                    canGoForward: false
                )
            )
        }

        let totalPages = max(1, Int(ceil(Double(totalRows) / Double(pageLimit))))
        let resolvedCurrentPage = min(max(1, currentPage), totalPages)
        let startIndex = (resolvedCurrentPage - 1) * pageLimit
        let endIndex = min(totalRows, startIndex + pageLimit)

        return KeywordPaginationContext(
            globalStartIndex: startIndex,
            sceneModel: ResultPaginationSceneModel(
                currentPage: resolvedCurrentPage,
                totalPages: totalPages,
                pageSizeLabel: pageSize.title(in: languageMode),
                rangeLabel: "\(startIndex + 1)-\(endIndex) / \(totalRows)",
                canGoBackward: resolvedCurrentPage > 1,
                canGoForward: resolvedCurrentPage < totalPages
            )
        )
    }

    func sliceRows(
        _ rows: [KeywordBuildRow],
        currentPage: Int,
        pageSize: KeywordPageSize
    ) -> ArraySlice<KeywordBuildRow> {
        guard let pageLimit = pageSize.rowLimit, pageLimit > 0 else {
            return rows[rows.indices]
        }
        guard !rows.isEmpty else { return [] }
        let totalPages = max(1, Int(ceil(Double(rows.count) / Double(pageLimit))))
        let resolvedCurrentPage = min(max(1, currentPage), totalPages)
        let startIndex = (resolvedCurrentPage - 1) * pageLimit
        let endIndex = min(rows.count, startIndex + pageLimit)
        return rows[startIndex..<endIndex]
    }
}

struct KeywordPaginationContext {
    let globalStartIndex: Int
    let sceneModel: ResultPaginationSceneModel
}
