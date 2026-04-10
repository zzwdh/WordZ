import Foundation

extension CompareSceneBuilder {
    func presentation(for key: CompareColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .word:
            return .keyword
        case .keyness, .effect, .range:
            return .numeric(precision: 2)
        case .spread, .total:
            return .numeric(precision: 0)
        case .distribution:
            return .summary
        case .dominantCorpus:
            return .label
        }
    }

    func widthPolicy(for key: CompareColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .word:
            return .keyword
        case .keyness, .effect, .spread, .total, .range:
            return .numeric
        case .distribution:
            return .summary
        case .dominantCorpus:
            return .standard
        }
    }

    func sortRows(_ rows: [DerivedCompareRow], mode: CompareSortMode) -> [DerivedCompareRow] {
        switch mode {
        case .keynessDescending:
            return rows.sorted {
                if $0.metrics.keyness == $1.metrics.keyness {
                    return $0.row.word.localizedCaseInsensitiveCompare($1.row.word) == .orderedAscending
                }
                return $0.metrics.keyness > $1.metrics.keyness
            }
        case .spreadDescending:
            return rows.sorted {
                if $0.row.spread == $1.row.spread {
                    if $0.row.total == $1.row.total {
                        return $0.row.word.localizedCaseInsensitiveCompare($1.row.word) == .orderedAscending
                    }
                    return $0.row.total > $1.row.total
                }
                return $0.row.spread > $1.row.spread
            }
        case .totalDescending:
            return rows.sorted {
                if $0.row.total == $1.row.total {
                    return $0.row.word.localizedCaseInsensitiveCompare($1.row.word) == .orderedAscending
                }
                return $0.row.total > $1.row.total
            }
        case .rangeDescending:
            return rows.sorted {
                if $0.metrics.range == $1.metrics.range {
                    return $0.row.word.localizedCaseInsensitiveCompare($1.row.word) == .orderedAscending
                }
                return $0.metrics.range > $1.metrics.range
            }
        case .effectDescending:
            return rows.sorted {
                if $0.metrics.effectSize == $1.metrics.effectSize {
                    return $0.row.word.localizedCaseInsensitiveCompare($1.row.word) == .orderedAscending
                }
                return $0.metrics.effectSize > $1.metrics.effectSize
            }
        case .alphabeticalAscending:
            return rows.sorted {
                $0.row.word.localizedCaseInsensitiveCompare($1.row.word) == .orderedAscending
            }
        }
    }

    func sortIndicator(for key: CompareColumnKey, sortMode: CompareSortMode) -> String? {
        switch (key, sortMode) {
        case (.word, .alphabeticalAscending):
            return "↑"
        case (.keyness, .keynessDescending),
             (.effect, .effectDescending),
             (.spread, .spreadDescending),
             (.total, .totalDescending),
             (.range, .rangeDescending):
            return "↓"
        default:
            return nil
        }
    }

    func buildPagination(
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

    func sliceRows<Row>(
        _ rows: [Row],
        currentPage: Int,
        pageSize: ComparePageSize
    ) -> ArraySlice<Row> {
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
