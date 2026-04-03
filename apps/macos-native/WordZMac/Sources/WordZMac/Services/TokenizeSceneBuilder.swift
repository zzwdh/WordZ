import Foundation

struct TokenizeSceneBuilder {
    @MainActor
    func build(
        from result: TokenizeResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        sortMode: TokenizeSortMode,
        pageSize: TokenizePageSize,
        currentPage: Int,
        visibleColumns: Set<TokenizeColumnKey>
    ) -> TokenizeSceneModel {
        let languageMode = WordZLocalization.shared.effectiveMode
        let filtered = SearchFilterSupport.filterWordLikeRows(
            result.tokens,
            query: query,
            options: searchOptions,
            stopword: stopwordFilter
        ) { $0.original }

        let filteredTokens = filtered.rows
        let sortedTokens = sortRows(filteredTokens, mode: sortMode)
        let pagination = buildPagination(
            totalRows: sortedTokens.count,
            currentPage: currentPage,
            pageSize: pageSize,
            languageMode: languageMode
        )
        let pageRows = sliceRows(sortedTokens, currentPage: pagination.currentPage, pageSize: pageSize)
        let sentenceTextByID = Dictionary(uniqueKeysWithValues: result.sentences.map { ($0.sentenceId, $0.text) })
        let sceneRows = pageRows.map { token in
            TokenizeSceneRow(
                id: token.id,
                sentenceText: sentenceTextByID[token.sentenceId] ?? "",
                sentenceLabel: "\(token.sentenceId + 1)",
                positionLabel: "\(token.tokenIndex + 1)",
                original: token.original,
                normalized: token.normalized
            )
        }
        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    TokenizeColumnKey.sentence.rawValue: row.sentenceLabel,
                    TokenizeColumnKey.position.rawValue: row.positionLabel,
                    TokenizeColumnKey.original.rawValue: row.original,
                    TokenizeColumnKey.normalized.rawValue: row.normalized
                ]
            )
        }

        let visibleSentenceCount = Set(filteredTokens.map(\.sentenceId)).count
        let exportDocument = buildExportDocument(
            from: filteredTokens,
            suggestedName: "tokenized-text.txt"
        )
        let metrics = [
            TokenizeMetricSceneItem(
                id: "sentences",
                title: wordZText("句子", "Sentences", mode: languageMode),
                value: "\(result.sentenceCount)"
            ),
            TokenizeMetricSceneItem(
                id: "tokens",
                title: wordZText("Token", "Tokens", mode: languageMode),
                value: "\(result.tokenCount)"
            ),
            TokenizeMetricSceneItem(
                id: "visible-sentences",
                title: wordZText("可见句子", "Visible Sentences", mode: languageMode),
                value: "\(visibleSentenceCount)"
            ),
            TokenizeMetricSceneItem(
                id: "filtered-tokens",
                title: wordZText("过滤后 Token", "Filtered Tokens", mode: languageMode),
                value: "\(filteredTokens.count)"
            )
        ]

        return TokenizeSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            metrics: metrics,
            sorting: TokenizeSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "tokenize",
                columns: TokenizeColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .sentence || key == .original
                    )
                },
                defaultDensity: .compact
            ),
            totalTokens: result.tokenCount,
            filteredTokens: filteredTokens.count,
            visibleTokens: sceneRows.count,
            totalSentences: result.sentenceCount,
            visibleSentences: visibleSentenceCount,
            rows: sceneRows,
            tableRows: tableRows,
            searchError: filtered.error,
            exportDocument: exportDocument
        )
    }

    private func presentation(for key: TokenizeColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .sentence, .position:
            return .numeric(precision: 0)
        case .original, .normalized:
            return .keyword
        }
    }

    private func widthPolicy(for key: TokenizeColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .sentence, .position:
            return .compact
        case .original, .normalized:
            return .keyword
        }
    }

    private func buildExportDocument(
        from filteredTokens: [TokenizedToken],
        suggestedName: String
    ) -> PlainTextExportDocument? {
        guard !filteredTokens.isEmpty else { return nil }
        let orderedTokens = filteredTokens.sorted {
            if $0.sentenceId == $1.sentenceId {
                return $0.tokenIndex < $1.tokenIndex
            }
            return $0.sentenceId < $1.sentenceId
        }
        let grouped = Dictionary(grouping: orderedTokens, by: \.sentenceId)
        let lines = grouped.keys.sorted().compactMap { sentenceID -> String? in
            guard let tokens = grouped[sentenceID], !tokens.isEmpty else { return nil }
            return tokens.map(\.normalized).joined(separator: " ")
        }
        guard !lines.isEmpty else { return nil }
        return PlainTextExportDocument(
            suggestedName: suggestedName,
            text: lines.joined(separator: "\n") + "\n"
        )
    }

    private func sortRows(_ rows: [TokenizedToken], mode: TokenizeSortMode) -> [TokenizedToken] {
        switch mode {
        case .sequenceAscending:
            return rows.sorted(by: sequenceAscending)
        case .sequenceDescending:
            return rows.sorted { sequenceAscending($1, $0) }
        case .originalAscending:
            return rows.sorted {
                compareText($0.original, $1.original, fallback: sequenceAscending($0, $1))
            }
        case .originalDescending:
            return rows.sorted {
                compareText($0.original, $1.original, fallback: sequenceAscending($0, $1), ascending: false)
            }
        case .normalizedAscending:
            return rows.sorted {
                compareText($0.normalized, $1.normalized, fallback: sequenceAscending($0, $1))
            }
        case .normalizedDescending:
            return rows.sorted {
                compareText($0.normalized, $1.normalized, fallback: sequenceAscending($0, $1), ascending: false)
            }
        }
    }

    private func sequenceAscending(_ lhs: TokenizedToken, _ rhs: TokenizedToken) -> Bool {
        if lhs.sentenceId == rhs.sentenceId {
            return lhs.tokenIndex < rhs.tokenIndex
        }
        return lhs.sentenceId < rhs.sentenceId
    }

    private func compareText(_ lhs: String, _ rhs: String, fallback: Bool, ascending: Bool = true) -> Bool {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        if comparison == .orderedSame {
            return fallback
        }
        return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    private func sortIndicator(for key: TokenizeColumnKey, sortMode: TokenizeSortMode) -> String? {
        switch (key, sortMode) {
        case (.sentence, .sequenceAscending), (.position, .sequenceAscending),
             (.original, .originalAscending), (.normalized, .normalizedAscending):
            return "↑"
        case (.sentence, .sequenceDescending), (.position, .sequenceDescending),
             (.original, .originalDescending), (.normalized, .normalizedDescending):
            return "↓"
        default:
            return nil
        }
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: TokenizePageSize,
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

    private func sliceRows(
        _ rows: [TokenizedToken],
        currentPage: Int,
        pageSize: TokenizePageSize
    ) -> ArraySlice<TokenizedToken> {
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
