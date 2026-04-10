import Foundation

struct KeywordSceneBuilder {
    func build(
        from result: KeywordResult,
        targetLabel: String,
        referenceLabel: String,
        options: KeywordPreprocessingOptions,
        hasPendingRunChanges: Bool,
        sortMode: KeywordSortMode,
        pageSize: KeywordPageSize,
        currentPage: Int,
        visibleColumns: Set<KeywordColumnKey>,
        languageMode: AppLanguageMode = .system
    ) -> KeywordSceneModel {
        let sortedRows = sortRows(result.rows, mode: sortMode)
        return build(
            from: result,
            targetLabel: targetLabel,
            referenceLabel: referenceLabel,
            options: options,
            hasPendingRunChanges: hasPendingRunChanges,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            languageMode: languageMode,
            sortedRows: sortedRows
        )
    }

    func build(
        from result: KeywordResult,
        targetLabel: String,
        referenceLabel: String,
        options: KeywordPreprocessingOptions,
        hasPendingRunChanges: Bool,
        sortMode: KeywordSortMode,
        pageSize: KeywordPageSize,
        currentPage: Int,
        visibleColumns: Set<KeywordColumnKey>,
        languageMode: AppLanguageMode = .system,
        sortedRows: [KeywordResultRow]
    ) -> KeywordSceneModel {
        let pagination = buildPagination(
            totalRows: sortedRows.count,
            currentPage: currentPage,
            pageSize: pageSize,
            languageMode: languageMode
        )
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)

        let sceneRows = pageRows.map { row in
            KeywordSceneRow(
                id: row.id,
                rankText: "\(row.rank)",
                word: row.word,
                targetFrequencyText: "\(row.targetFrequency)",
                referenceFrequencyText: "\(row.referenceFrequency)",
                targetNormFrequencyText: String(format: "%.1f", row.targetNormalizedFrequency),
                referenceNormFrequencyText: String(format: "%.1f", row.referenceNormalizedFrequency),
                scoreText: String(format: "%.2f", row.keynessScore),
                logRatioText: String(format: "%.2f", row.logRatio),
                pValueText: row.pValue < 0.001 ? "<0.001" : String(format: "%.3f", row.pValue)
            )
        }

        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    KeywordColumnKey.rank.rawValue: row.rankText,
                    KeywordColumnKey.word.rawValue: row.word,
                    KeywordColumnKey.targetFrequency.rawValue: row.targetFrequencyText,
                    KeywordColumnKey.referenceFrequency.rawValue: row.referenceFrequencyText,
                    KeywordColumnKey.targetNormFrequency.rawValue: row.targetNormFrequencyText,
                    KeywordColumnKey.referenceNormFrequency.rawValue: row.referenceNormFrequencyText,
                    KeywordColumnKey.score.rawValue: row.scoreText,
                    KeywordColumnKey.logRatio.rawValue: row.logRatioText,
                    KeywordColumnKey.pValue.rawValue: row.pValueText
                ]
            )
        }

        let preprocessingSummary = buildPreprocessingSummary(options: options, languageMode: languageMode)
        let methodSummary = buildMethodSummary(options: options, hasPendingRunChanges: hasPendingRunChanges, languageMode: languageMode)
        let methodNotes = buildMethodNotes(options: options, languageMode: languageMode)
        let exportMetadataLines = AnalysisExportMetadataSupport.notes(
            analysisTitle: wordZText("关键词分析", "Keyword Analysis", mode: languageMode),
            languageMode: languageMode,
            visibleRows: sceneRows.count,
            totalRows: result.rows.count,
            query: "",
            searchOptions: .default,
            stopwordFilter: options.stopwordFilter,
            additionalLines: [
                "\(wordZText("Target 语料", "Target Corpus", mode: languageMode)): \(targetLabel)",
                "\(wordZText("Reference 语料", "Reference Corpus", mode: languageMode)): \(referenceLabel)",
                preprocessingSummary
            ]
        )

        return KeywordSceneModel(
            targetSummary: "\(targetLabel) · \(wordZText("tokens", "tokens", mode: languageMode)) \(result.targetCorpus.tokenCount) · \(wordZText("types", "types", mode: languageMode)) \(result.targetCorpus.typeCount)",
            referenceSummary: "\(referenceLabel) · \(wordZText("tokens", "tokens", mode: languageMode)) \(result.referenceCorpus.tokenCount) · \(wordZText("types", "types", mode: languageMode)) \(result.referenceCorpus.typeCount)",
            preprocessingSummary: preprocessingSummary,
            methodSummary: methodSummary,
            methodNotes: methodNotes,
            exportMetadataLines: exportMetadataLines,
            sorting: KeywordSortingSceneModel(selectedSort: sortMode, selectedPageSize: pageSize),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "keyword",
                columns: KeywordColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode, statistic: result.statistic),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .rank || key == .word
                    )
                },
                defaultDensity: .standard
            ),
            totalRows: result.rows.count,
            visibleRows: sceneRows.count,
            rows: sceneRows,
            tableRows: tableRows
        )
    }

    private func buildPreprocessingSummary(
        options: KeywordPreprocessingOptions,
        languageMode: AppLanguageMode
    ) -> String {
        let lowercaseText = options.lowercased
            ? wordZText("小写化开启", "Lowercasing on", mode: languageMode)
            : wordZText("保留大小写", "Preserve case", mode: languageMode)
        let punctuationText = options.removePunctuation
            ? wordZText("去标点", "Remove punctuation", mode: languageMode)
            : wordZText("保留连字符/撇号", "Preserve joiners", mode: languageMode)
        let minFreqText = "\(wordZText("最小 Target 频次", "Min Target Frequency", mode: languageMode)): \(max(1, options.minimumFrequency))"
        let stopwordText = options.stopwordFilter.summaryText(in: languageMode)
        return [lowercaseText, punctuationText, minFreqText, stopwordText].joined(separator: " · ")
    }

    private func buildMethodSummary(
        options: KeywordPreprocessingOptions,
        hasPendingRunChanges: Bool,
        languageMode: AppLanguageMode
    ) -> String {
        let statisticSummary: String
        switch options.statistic {
        case .logLikelihood:
            statisticSummary = wordZText(
                "当前使用 Log-Likelihood 计算 keyness。结果仅保留在 Target 中标准化频率高于 Reference 的词项，因此这里显示的是典型意义上的关键词，而不是简单高频词。",
                "WordZ is currently using Log-Likelihood for keyness. Only terms whose normalized frequency is higher in the target corpus than in the reference corpus are retained, so these rows represent true keywords rather than mere high-frequency terms.",
                mode: languageMode
            )
        case .chiSquare:
            statisticSummary = wordZText(
                "当前使用 Chi-square 作为关键词显著性统计量。结果仍基于 Target 与 Reference 的相对频率差异，而不是原始总频次。",
                "WordZ is currently using Chi-square as the keyword significance statistic. The ranking still reflects relative frequency differences between the target and reference corpora rather than raw totals alone.",
                mode: languageMode
            )
        }
        guard !hasPendingRunChanges else {
            return statisticSummary + " " + wordZText(
                "你已经修改了语料或预处理参数，当前表格仍基于上次运行结果。",
                "You have changed the corpora or preprocessing options, but the table still reflects the last completed run.",
                mode: languageMode
            )
        }
        return statisticSummary
    }

    private func buildMethodNotes(
        options: KeywordPreprocessingOptions,
        languageMode: AppLanguageMode
    ) -> [String] {
        [
            wordZText(
                "关键词并不等于高频词，而是指在 Target 相对 Reference 更显著的词项。",
                "Keywords are not simply frequent words; they are terms that are statistically more distinctive in the target corpus than in the reference corpus.",
                mode: languageMode
            ),
            wordZText(
                "标准频率统一按每百万词计算，可以在语料规模不同的情况下保持可比性。",
                "Normalized frequencies are reported per million words so that corpora of different sizes remain comparable.",
                mode: languageMode
            ),
            options.minimumFrequency > 1
                ? wordZText(
                    "当前启用了最低频次阈值，用来筛掉极低频、偶发的词项。",
                    "A minimum frequency threshold is active to remove extremely rare, accidental terms.",
                    mode: languageMode
                )
                : wordZText(
                    "当前未提高最低频次阈值，极低频词可能仍会进入结果，解释时要更谨慎。",
                    "The minimum frequency threshold is low, so rare terms may still appear and should be interpreted cautiously.",
                    mode: languageMode
                )
        ]
    }

    func sortRows(_ rows: [KeywordResultRow], mode: KeywordSortMode) -> [KeywordResultRow] {
        switch mode {
        case .scoreDescending:
            return rows.sorted {
                if $0.keynessScore == $1.keynessScore {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.keynessScore > $1.keynessScore
            }
        case .targetFrequencyDescending:
            return rows.sorted {
                if $0.targetFrequency == $1.targetFrequency {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.targetFrequency > $1.targetFrequency
            }
        case .targetNormFrequencyDescending:
            return rows.sorted {
                if $0.targetNormalizedFrequency == $1.targetNormalizedFrequency {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.targetNormalizedFrequency > $1.targetNormalizedFrequency
            }
        case .alphabeticalAscending:
            return rows.sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
        }
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: KeywordPageSize,
        languageMode: AppLanguageMode
    ) -> ResultPaginationSceneModel {
        guard let pageLimit = pageSize.rowLimit, pageLimit > 0 else {
            let totalLabel = wordZText("全部", "All", mode: languageMode)
            return ResultPaginationSceneModel(
                currentPage: 1,
                totalPages: 1,
                pageSizeLabel: pageSize.title(in: languageMode),
                rangeLabel: totalRows == 0 ? totalLabel : "1-\(totalRows) / \(totalRows)",
                canGoBackward: false,
                canGoForward: false
            )
        }

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

        let totalPages = max(1, Int(ceil(Double(totalRows) / Double(pageLimit))))
        let resolvedPage = min(max(1, currentPage), totalPages)
        let startIndex = (resolvedPage - 1) * pageLimit + 1
        let endIndex = min(totalRows, startIndex + pageLimit - 1)

        return ResultPaginationSceneModel(
            currentPage: resolvedPage,
            totalPages: totalPages,
            pageSizeLabel: pageSize.title(in: languageMode),
            rangeLabel: "\(startIndex)-\(endIndex) / \(totalRows)",
            canGoBackward: resolvedPage > 1,
            canGoForward: resolvedPage < totalPages
        )
    }

    private func sliceRows(
        _ rows: [KeywordResultRow],
        currentPage: Int,
        pageSize: KeywordPageSize
    ) -> [KeywordResultRow] {
        guard let pageLimit = pageSize.rowLimit, pageLimit > 0 else { return rows }
        let start = max(0, (currentPage - 1) * pageLimit)
        guard start < rows.count else { return [] }
        let end = min(rows.count, start + pageLimit)
        return Array(rows[start..<end])
    }

    private func presentation(for key: KeywordColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .word:
            return .keyword
        case .rank, .targetFrequency, .referenceFrequency:
            return .numeric(precision: 0)
        case .targetNormFrequency, .referenceNormFrequency, .score, .logRatio:
            return .numeric(precision: 2)
        case .pValue:
            return .numeric(precision: 3)
        }
    }

    private func widthPolicy(for key: KeywordColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .word:
            return .keyword
        default:
            return .numeric
        }
    }

    private func sortIndicator(for key: KeywordColumnKey, sortMode: KeywordSortMode) -> String? {
        switch (key, sortMode) {
        case (.score, .scoreDescending),
             (.targetFrequency, .targetFrequencyDescending),
             (.targetNormFrequency, .targetNormFrequencyDescending):
            return "▼"
        case (.word, .alphabeticalAscending):
            return "▲"
        default:
            return nil
        }
    }
}
