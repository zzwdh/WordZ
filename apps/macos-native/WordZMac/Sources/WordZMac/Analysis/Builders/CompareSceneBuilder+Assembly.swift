import Foundation

struct CompareMethodDetails {
    let referenceSummary: String
    let methodSummary: String
    let methodNotes: [String]
    let selectedTitles: [String]
}

extension CompareSceneBuilder {
    func buildDerivedRows(
        from rows: [CompareRow],
        referenceSelection: CompareReferenceSelection,
        referenceCorpusSets: [LibraryCorpusSetItem],
        languageMode: AppLanguageMode
    ) -> [DerivedCompareRow] {
        let resolvedReference = resolveReferenceSelection(
            referenceSelection,
            selection: rows.first?.perCorpus.map {
                CompareSelectableCorpusSceneItem(
                    id: $0.corpusId,
                    title: $0.corpusName,
                    subtitle: $0.folderName,
                    isSelected: true
                )
            } ?? [],
            referenceCorpusSets: referenceCorpusSets
        )
        return rows.map { row in
            DerivedCompareRow(
                row: row,
                metrics: deriveMetrics(
                    for: row,
                    referenceCorpusIDs: resolvedReference.corpusIDs,
                    referenceLabel: resolvedReference.label,
                    languageMode: languageMode
                )
            )
        }
    }

    func buildSceneRows(from items: [DerivedCompareRow]) -> [CompareSceneRow] {
        items.map { item in
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
    }

    func buildTableRows(from sceneRows: [CompareSceneRow]) -> [NativeTableRowDescriptor] {
        sceneRows.map { row in
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
    }

    func buildCorpusSummaries(
        from corpora: [CompareCorpusSummary],
        languageMode: AppLanguageMode
    ) -> [CompareCorpusSummarySceneItem] {
        corpora.map { corpus in
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
    }

    func buildMethodDetails(
        selection: [CompareSelectableCorpusSceneItem],
        referenceSelection: CompareReferenceSelection,
        referenceCorpusSets: [LibraryCorpusSetItem],
        languageMode: AppLanguageMode
    ) -> CompareMethodDetails {
        let resolvedReference = resolveReferenceSelection(
            referenceSelection,
            selection: selection,
            referenceCorpusSets: referenceCorpusSets
        )
        let selectedTitles = selection
            .filter { $0.isSelected && !resolvedReference.corpusIDs.contains($0.id) }
            .map(\.title)

        if case .corpus = referenceSelection,
           let referenceItem = selection.first(where: { $0.id == resolvedReference.corpusIDs.first }) {
            let targetItems = selection.filter { $0.isSelected && !resolvedReference.corpusIDs.contains($0.id) }
            let targetSummary = targetItems.isEmpty
                ? wordZText("未选择目标语料", "No target corpora selected", mode: languageMode)
                : targetItems.map(\.title).joined(separator: " · ")
            let referenceSummary = wordZText("参考语料：", "Reference Corpus: ", mode: languageMode) + referenceItem.title + " · " + wordZText("目标语料：", "Target Corpora: ", mode: languageMode) + targetSummary
            let methodSummary = wordZText(
                "当前结果使用固定参考语料。系统会把所选参考语料与其余已选语料合并后的目标语料组做 keyness 比较，因此更适合做可复现的对比实验。",
                "These results use a fixed reference corpus. WordZ compares the chosen reference corpus against the pooled target set formed by the remaining selected corpora, which is better suited to reproducible comparative studies.",
                mode: languageMode
            )
            let methodNotes = [
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
            return CompareMethodDetails(
                referenceSummary: referenceSummary,
                methodSummary: methodSummary,
                methodNotes: methodNotes,
                selectedTitles: selectedTitles
            )
        }

        if case .corpusSet = referenceSelection,
           let referenceLabel = resolvedReference.label {
            let targetSummary = selectedTitles.isEmpty
                ? wordZText("未选择目标语料", "No target corpora selected", mode: languageMode)
                : selectedTitles.joined(separator: " · ")
            let referenceSummary = wordZText("参考语料集：", "Reference Set: ", mode: languageMode) + referenceLabel + " · " + wordZText("目标语料：", "Target Corpora: ", mode: languageMode) + targetSummary
            let methodSummary = wordZText(
                "当前结果使用命名参考语料集。系统会把参考语料集中的语料合并为一组，并与当前所选目标语料组做 keyness 比较，更适合做稳定的课程作业和论文复现实验。",
                "These results use a named reference corpus set. WordZ merges the saved reference-set corpora into one reference group and compares it against the current target selection, which is better suited to reproducible coursework and research workflows.",
                mode: languageMode
            )
            let methodNotes = [
                wordZText(
                    "参考语料集中的语料会被合并计算；如果某条语料同时属于目标和参考集合，系统会优先把它视为参考侧。",
                    "Corpora inside the saved reference set are pooled into a single reference group. If a corpus appears in both target and reference selections, WordZ treats it as part of the reference side.",
                    mode: languageMode
                ),
                wordZText(
                    "阅读结果时，建议同时看 Keyness、Log Ratio 和完整分布，确认差异是否来自整体频率还是单个语料偏高。",
                    "Read Keyness together with Log Ratio and the full distribution to tell whether a contrast comes from the whole target set or a single corpus spike.",
                    mode: languageMode
                )
            ]
            return CompareMethodDetails(
                referenceSummary: referenceSummary,
                methodSummary: methodSummary,
                methodNotes: methodNotes,
                selectedTitles: selectedTitles
            )
        }

        return CompareMethodDetails(
            referenceSummary: wordZText(
                "参考语料：自动按词项确定",
                "Reference corpus: chosen automatically per word",
                mode: languageMode
            ),
            methodSummary: wordZText(
                "Keyness 使用带方向的 log-likelihood，并辅以 Log Ratio 作为效应值。每个词都把标准化频次最高的语料视为目标语料，其余所选语料合并为参考语料。",
                "Keyness uses signed log-likelihood, with Log Ratio as the effect size. For each word, the corpus with the highest normalized frequency is treated as the target corpus and the remaining selected corpora are merged into the reference corpus.",
                mode: languageMode
            ),
            methodNotes: [
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
            ],
            selectedTitles: selectedTitles
        )
    }

    func buildExportMetadata(
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        annotationSummary: String,
        sentimentSummary: CompareSentimentSummary?,
        sentimentExplainer: CompareSentimentExplainer?,
        referenceSummary: String,
        selectedTitles: [String],
        visibleRows: Int,
        totalRows: Int,
        languageMode: AppLanguageMode
    ) -> [String] {
        AnalysisExportMetadataSupport.notes(
            analysisTitle: wordZText("语料对比 / Keyness", "Corpus Compare / Keyness", mode: languageMode),
            languageMode: languageMode,
            visibleRows: visibleRows,
            totalRows: totalRows,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            additionalLines: [
                "\(wordZText("参考口径", "Reference Scope", mode: languageMode)): \(referenceSummary)",
                "\(wordZText("所选语料", "Selected Corpora", mode: languageMode)): \(selectedTitles.isEmpty ? "—" : selectedTitles.joined(separator: " · "))",
                annotationSummary
            ] + (sentimentSummary?.exportMetadataLines(in: languageMode) ?? [])
                + (sentimentExplainer?.exportMetadataLines(in: languageMode) ?? [])
        )
    }

    func resolveReferenceSelection(
        _ selection: CompareReferenceSelection,
        selection items: [CompareSelectableCorpusSceneItem],
        referenceCorpusSets: [LibraryCorpusSetItem]
    ) -> (corpusIDs: Set<String>, label: String?) {
        switch selection {
        case .automatic:
            return ([], nil)
        case .corpus(let corpusID):
            let label = items.first(where: { $0.id == corpusID })?.title
            return (label == nil ? [] : [corpusID], label)
        case .corpusSet(let corpusSetID):
            guard let corpusSet = referenceCorpusSets.first(where: { $0.id == corpusSetID }) else {
                return ([], nil)
            }
            return (Set(corpusSet.corpusIDs), corpusSet.name)
        }
    }
}
