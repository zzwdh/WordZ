import Foundation

struct CompareSceneBuilder {
    func build(
        selection: [CompareSelectableCorpusSceneItem],
        from result: CompareResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        referenceCorpusID: String? = nil,
        sortMode: CompareSortMode,
        pageSize: ComparePageSize,
        currentPage: Int,
        visibleColumns: Set<CompareColumnKey>,
        languageMode: AppLanguageMode = .system
    ) -> CompareSceneModel {
        let filtered = SearchFilterSupport.filterWordLikeRows(
            result.rows,
            query: query,
            options: searchOptions,
            stopword: stopwordFilter
        ) { $0.word }
        let derivedRows = filtered.rows.map { row in
            DerivedCompareRow(
                row: row,
                metrics: deriveMetrics(
                    for: row,
                    referenceCorpusID: referenceCorpusID,
                    languageMode: languageMode
                )
            )
        }
        let sortedRows = sortRows(derivedRows, mode: sortMode)
        let pagination = buildPagination(totalRows: sortedRows.count, currentPage: currentPage, pageSize: pageSize, languageMode: languageMode)
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)

        let sceneRows = pageRows.map { item in
            let row = item.row
            let metrics = item.metrics
            return CompareSceneRow(
                id: row.id,
                word: row.word,
                keynessText: String(format: "%.2f", metrics.keyness),
                effectText: String(format: "%.2f", metrics.effectSize),
                pValueText: metrics.pValue < 0.001 ? "<0.001" : String(format: "%.3f", metrics.pValue),
                spreadText: "\(row.spread)",
                totalText: "\(row.total)",
                rangeText: String(format: "%.2f", metrics.range),
                referenceNormFreqText: String(format: "%.1f", metrics.referenceNormFreq),
                referenceLabelText: metrics.referenceLabel,
                dominantCorpus: metrics.dominantLabel,
                distributionText: metrics.distributionText
            )
        }
        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    CompareColumnKey.word.rawValue: row.word,
                    CompareColumnKey.keyness.rawValue: row.keynessText,
                    CompareColumnKey.effect.rawValue: row.effectText,
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
        let selectedTitles = selection.filter(\.isSelected).map(\.title)
        let referenceSummary: String
        let methodSummary: String
        let methodNotes: [String]
        if let referenceCorpusID,
           let referenceItem = selection.first(where: { $0.id == referenceCorpusID }) {
            let targetItems = selection.filter { $0.isSelected && $0.id != referenceCorpusID }
            let targetSummary = targetItems.isEmpty
                ? wordZText("未选择目标语料", "No target corpora selected", mode: languageMode)
                : targetItems.map(\.title).joined(separator: " · ")
            referenceSummary = wordZText("参考语料：", "Reference Corpus: ", mode: languageMode) + referenceItem.title + " · " + wordZText("目标语料：", "Target Corpora: ", mode: languageMode) + targetSummary
            methodSummary = wordZText(
                "当前结果使用固定参考语料。系统会把所选参考语料与其余已选语料合并后的目标语料组做 keyness 比较，因此更适合做可复现的对比实验。",
                "These results use a fixed reference corpus. WordZ compares the chosen reference corpus against the pooled target set formed by the remaining selected corpora, which is better suited to reproducible comparative studies.",
                mode: languageMode
            )
            methodNotes = [
                wordZText(
                    "Keyness 为正时，表示该词在目标语料组更突出；为负时，表示该词在参考语料更突出。",
                    "A positive Keyness means the word is more prominent in the target set; a negative value means it is more prominent in the reference corpus.",
                    mode: languageMode
                ),
                wordZText(
                    "如果只选了两条语料，这个模式就是严格的一对一对比。",
                    "When exactly two corpora are selected, this becomes a strict one-to-one comparison.",
                    mode: languageMode
                )
            ]
        } else {
            referenceSummary = wordZText(
                "参考语料：自动按词项确定",
                "Reference corpus: chosen automatically per word",
                mode: languageMode
            )
            methodSummary = wordZText(
                "Keyness 使用带方向的 log-likelihood，并辅以 Log Ratio 作为效应值。每个词都把标准化频次最高的语料视为目标语料，其余所选语料合并为参考语料。",
                "Keyness uses signed log-likelihood, with Log Ratio as the effect size. For each word, the corpus with the highest normalized frequency is treated as the target corpus and the remaining selected corpora are merged into the reference corpus.",
                mode: languageMode
            )
            methodNotes = [
                wordZText(
                    "Keyness 适合找“在哪个语料里显著更突出”的词，而不只是看总频次。",
                    "Keyness helps identify which corpus makes a word statistically distinctive, not just more frequent in raw counts.",
                    mode: languageMode
                ),
                wordZText(
                    "阅读结果时，建议同时看 Keyness、Log Ratio 和完整分布。",
                    "Read Keyness together with Log Ratio and the full per-corpus distribution for a more reliable interpretation.",
                    mode: languageMode
                )
            ]
        }
        let exportMetadataLines = AnalysisExportMetadataSupport.notes(
            analysisTitle: wordZText("语料对比 / Keyness", "Corpus Compare / Keyness", mode: languageMode),
            languageMode: languageMode,
            visibleRows: sceneRows.count,
            totalRows: sortedRows.count,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            additionalLines: [
                "\(wordZText("参考口径", "Reference Scope", mode: languageMode)): \(referenceSummary)",
                "\(wordZText("所选语料", "Selected Corpora", mode: languageMode)): \(selectedTitles.isEmpty ? "—" : selectedTitles.joined(separator: " · "))"
            ]
        )

        return CompareSceneModel(
            selection: selection,
            corpusSummaries: summaries,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            referenceSummary: referenceSummary,
            methodSummary: methodSummary,
            methodNotes: methodNotes,
            exportMetadataLines: exportMetadataLines,
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
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .word || key == .keyness
                    )
                },
                defaultDensity: .standard
            ),
            totalRows: result.rows.count,
            filteredRows: sortedRows.count,
            visibleRows: sceneRows.count,
            rows: sceneRows,
            tableRows: tableRows,
            searchError: filtered.error
        )
    }

    private func presentation(for key: CompareColumnKey) -> NativeTableColumnPresentation {
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

    private func widthPolicy(for key: CompareColumnKey) -> NativeTableColumnWidthPolicy {
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

    private func sortRows(_ rows: [DerivedCompareRow], mode: CompareSortMode) -> [DerivedCompareRow] {
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

    private func sortIndicator(for key: CompareColumnKey, sortMode: CompareSortMode) -> String? {
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

    private func sliceRows<Row>(
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

    private func deriveMetrics(
        for row: CompareRow,
        referenceCorpusID: String?,
        languageMode: AppLanguageMode
    ) -> DerivedCompareMetrics {
        guard let referenceCorpusID,
              let reference = row.perCorpus.first(where: { $0.corpusId == referenceCorpusID }) else {
            return DerivedCompareMetrics(
                keyness: row.keyness,
                effectSize: row.effectSize,
                pValue: row.pValue,
                range: row.range,
                referenceNormFreq: row.referenceNormFreq,
                referenceLabel: wordZText("自动参考语料", "Automatic Reference", mode: languageMode),
                dominantLabel: row.dominantCorpusName,
                distributionText: row.perCorpus
                    .map { "\($0.corpusName) \($0.count) (\(String(format: "%.1f", $0.normFreq)))" }
                    .joined(separator: " · ")
            )
        }

        let targets = row.perCorpus.filter { $0.corpusId != referenceCorpusID }
        let targetCount = targets.reduce(0) { $0 + $1.count }
        let targetTokenCount = targets.reduce(0) { $0 + $1.tokenCount }
        let targetNormFreq = targetTokenCount > 0
            ? (Double(targetCount) / Double(targetTokenCount)) * 10_000
            : 0
        let keyness = signedLogLikelihood(
            targetCount: targetCount,
            targetTokenCount: targetTokenCount,
            referenceCount: reference.count,
            referenceTokenCount: reference.tokenCount
        )
        let effectSize = logRatio(
            targetCount: targetCount,
            targetTokenCount: targetTokenCount,
            referenceCount: reference.count,
            referenceTokenCount: reference.tokenCount
        )
        let pValue = erfc(sqrt(abs(keyness) / 2))
        let targetLabel: String
        if targets.count == 1 {
            targetLabel = targets[0].corpusName
        } else {
            targetLabel = wordZText("目标语料组", "Target Set", mode: languageMode)
        }
        let dominantLabel = keyness >= 0 ? targetLabel : reference.corpusName
        let distributionText = row.perCorpus
            .map { corpus in
                let marker = corpus.corpusId == referenceCorpusID ? " [REF]" : ""
                return "\(corpus.corpusName)\(marker) \(corpus.count) (\(String(format: "%.1f", corpus.normFreq)))"
            }
            .joined(separator: " · ")

        return DerivedCompareMetrics(
            keyness: keyness,
            effectSize: effectSize,
            pValue: pValue,
            range: abs(targetNormFreq - reference.normFreq),
            referenceNormFreq: reference.normFreq,
            referenceLabel: reference.corpusName,
            dominantLabel: dominantLabel,
            distributionText: distributionText
        )
    }

    private func signedLogLikelihood(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let target = Double(max(0, targetCount))
        let reference = Double(max(0, referenceCount))
        let targetTotal = Double(max(0, targetTokenCount))
        let referenceTotal = Double(max(0, referenceTokenCount))
        let grandTotal = targetTotal + referenceTotal
        let observedTotal = target + reference

        guard targetTotal > 0, referenceTotal > 0, grandTotal > 0, observedTotal > 0 else {
            return 0
        }

        let pooledRate = observedTotal / grandTotal
        let expectedTarget = targetTotal * pooledRate
        let expectedReference = referenceTotal * pooledRate
        let targetTerm = target > 0 && expectedTarget > 0 ? target * log(target / expectedTarget) : 0
        let referenceTerm = reference > 0 && expectedReference > 0 ? reference * log(reference / expectedReference) : 0
        let statistic = 2 * (targetTerm + referenceTerm)

        let targetRate = target / targetTotal
        let referenceRate = reference / referenceTotal
        let sign = targetRate >= referenceRate ? 1.0 : -1.0
        return statistic * sign
    }

    private func logRatio(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let targetRate = (Double(max(0, targetCount)) + 0.5) / (Double(max(0, targetTokenCount)) + 1)
        let referenceRate = (Double(max(0, referenceCount)) + 0.5) / (Double(max(0, referenceTokenCount)) + 1)
        guard targetRate > 0, referenceRate > 0 else { return 0 }
        return log2(targetRate / referenceRate)
    }
}

private struct DerivedCompareRow {
    let row: CompareRow
    let metrics: DerivedCompareMetrics
}

private struct DerivedCompareMetrics {
    let keyness: Double
    let effectSize: Double
    let pValue: Double
    let range: Double
    let referenceNormFreq: Double
    let referenceLabel: String
    let dominantLabel: String
    let distributionText: String
}
