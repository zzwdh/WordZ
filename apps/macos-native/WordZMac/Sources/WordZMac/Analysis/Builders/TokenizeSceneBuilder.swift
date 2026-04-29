import Foundation

struct TokenizeSceneBuilder {
    func build(
        from result: TokenizeResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        languagePreset: TokenizeLanguagePreset,
        annotationProfile: WorkspaceAnnotationProfile = .surface,
        lemmaStrategy: TokenLemmaStrategy,
        sortMode: TokenizeSortMode,
        pageSize: TokenizePageSize,
        currentPage: Int,
        visibleColumns: Set<TokenizeColumnKey>,
        languageMode: AppLanguageMode = .system
    ) -> TokenizeSceneModel {
        let presetFilteredTokens = filterPresetTokens(from: result, languagePreset: languagePreset)
        let filtered = filterRows(
            presetFilteredTokens,
            query: query,
            options: searchOptions,
            stopword: stopwordFilter,
            lemmaStrategy: lemmaStrategy
        )

        let sortedTokens = sortRows(filtered.rows, mode: sortMode, lemmaStrategy: lemmaStrategy)
        return build(
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            languagePreset: languagePreset,
            annotationProfile: annotationProfile,
            lemmaStrategy: lemmaStrategy,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            languageMode: languageMode,
            presetFilteredTokens: presetFilteredTokens,
            filteredTokens: filtered.rows,
            sortedTokens: sortedTokens,
            searchError: filtered.error
        )
    }

    func build(
        from result: TokenizeResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        languagePreset: TokenizeLanguagePreset,
        annotationProfile: WorkspaceAnnotationProfile = .surface,
        lemmaStrategy: TokenLemmaStrategy,
        sortMode: TokenizeSortMode,
        pageSize: TokenizePageSize,
        currentPage: Int,
        visibleColumns: Set<TokenizeColumnKey>,
        languageMode: AppLanguageMode = .system,
        presetFilteredTokens: [TokenizedToken],
        filteredTokens: [TokenizedToken],
        sortedTokens: [TokenizedToken],
        searchError: String
    ) -> TokenizeSceneModel {
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
                normalized: token.normalized,
                lemma: token.annotations.lemma ?? "—",
                lexicalClass: token.annotations.lexicalClass?.title(in: languageMode) ?? wordZText("未标注", "Unlabeled", mode: languageMode),
                script: token.annotations.script.title(in: languageMode)
            )
        }
        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    TokenizeColumnKey.sentence.rawValue: row.sentenceLabel,
                    TokenizeColumnKey.position.rawValue: row.positionLabel,
                    TokenizeColumnKey.original.rawValue: row.original,
                    TokenizeColumnKey.normalized.rawValue: row.normalized,
                    TokenizeColumnKey.lemma.rawValue: row.lemma,
                    TokenizeColumnKey.lexicalClass.rawValue: row.lexicalClass,
                    TokenizeColumnKey.script.rawValue: row.script
                ]
            )
        }

        let visibleSentenceCount = Set(filteredTokens.map(\.sentenceId)).count
        let exportDocument = buildExportDocument(
            from: filteredTokens,
            lemmaStrategy: lemmaStrategy,
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
            ),
            TokenizeMetricSceneItem(
                id: "preset-tokens",
                title: wordZText("预设保留 Token", "Preset-kept Tokens", mode: languageMode),
                value: "\(presetFilteredTokens.count)"
            )
        ]

        return TokenizeSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            languagePreset: languagePreset,
            languagePresetSummary: languagePreset.summary(in: languageMode),
            annotationSummary: annotationProfile.summary(in: languageMode),
            lemmaStrategy: lemmaStrategy,
            lemmaStrategySummary: lemmaStrategy.summary(in: languageMode),
            metrics: metrics,
            sorting: TokenizeSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize,
                selectedLanguagePreset: languagePreset,
                selectedLemmaStrategy: lemmaStrategy
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
            tableSnapshot: ResultTableSnapshot.stable(rows: tableRows),
            searchError: searchError,
            exportDocument: exportDocument
        )
    }

    func filterPresetTokens(
        from result: TokenizeResult,
        languagePreset: TokenizeLanguagePreset
    ) -> [TokenizedToken] {
        result.tokens.filter { languagePreset.keeps($0.annotations) }
    }

    func presentation(for key: TokenizeColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .sentence, .position:
            return .numeric(precision: 0)
        case .original, .normalized, .lemma:
            return .keyword
        case .lexicalClass, .script:
            return .label
        }
    }

    func widthPolicy(for key: TokenizeColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .sentence, .position:
            return .compact
        case .script:
            return .compact
        case .lexicalClass:
            return .standard
        case .original, .normalized, .lemma:
            return .keyword
        }
    }
}
