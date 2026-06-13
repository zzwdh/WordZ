import Foundation

extension KeywordSceneBuilder {
    func buildSceneRow(
        _ row: KeywordBuildRow,
        globalRank: Int,
        languageMode: AppLanguageMode
    ) -> KeywordSceneRow {
        let pValueText: String
        if row.pValue <= 0 {
            pValueText = ""
        } else if row.pValue < 0.001 {
            pValueText = "<0.001"
        } else {
            pValueText = String(format: "%.3f", row.pValue)
        }

        return KeywordSceneRow(
            id: row.id,
            kind: row.kind,
            rankText: "\(globalRank)",
            item: row.item,
            directionText: row.direction?.title(in: languageMode) ?? "",
            focusFrequencyText: row.focusFrequency > 0 ? "\(row.focusFrequency)" : "",
            referenceFrequencyText: row.referenceFrequency > 0 ? "\(row.referenceFrequency)" : "",
            focusNormFrequencyText: row.focusNormFrequency > 0 ? String(format: "%.1f", row.focusNormFrequency) : "",
            referenceNormFrequencyText: row.referenceNormFrequency > 0 ? String(format: "%.1f", row.referenceNormFrequency) : "",
            keynessText: row.keyness != 0 ? String(format: "%.2f", row.keyness) : "",
            logRatioText: row.logRatio != 0 ? String(format: "%.2f", row.logRatio) : "",
            pValueText: pValueText,
            focusRangeText: row.focusRange > 0 ? "\(row.focusRange)" : "",
            referenceRangeText: row.referenceRange > 0 ? "\(row.referenceRange)" : "",
            exampleText: row.example,
            diffStatusText: row.diffStatus.map { diffStatusTitle($0, mode: languageMode) } ?? "",
            leftRankText: row.leftRank.map(String.init) ?? "",
            rightRankText: row.rightRank.map(String.init) ?? "",
            logRatioDeltaText: row.logRatioDelta != 0 ? String(format: "%.2f", row.logRatioDelta) : "",
            coverageCountText: row.coverageCount > 0 ? "\(row.coverageCount)" : "",
            coverageRateText: row.coverageRate > 0 ? String(format: "%.2f", row.coverageRate) : "",
            meanKeynessText: row.meanKeyness > 0 ? String(format: "%.2f", row.meanKeyness) : "",
            meanAbsLogRatioText: row.meanAbsLogRatio > 0 ? String(format: "%.2f", row.meanAbsLogRatio) : "",
            lastSeenAtText: row.lastSeenAt
        )
    }

    func buildFocusSummary(
        result: KeywordSuiteResult?,
        fallback: String,
        languageMode: AppLanguageMode
    ) -> String {
        guard let summary = result?.focusSummary else { return fallback }
        return [
            summary.label,
            "\(wordZText("语料", "Corpora", mode: languageMode)) \(summary.corpusCount)",
            "\(wordZText("词数", "tokens", mode: languageMode)) \(summary.tokenCount)",
            "\(wordZText("不同词项", "types", mode: languageMode)) \(summary.typeCount)"
        ].joined(separator: " · ")
    }

    func buildReferenceSummary(
        result: KeywordSuiteResult?,
        fallback: String,
        languageMode: AppLanguageMode
    ) -> String {
        guard let summary = result?.referenceSummary else { return fallback }
        let scopeLabel = summary.isWordList
            ? wordZText("词表", "Word List", mode: languageMode)
            : wordZText("语料", "Corpora", mode: languageMode)
        return [
            summary.label,
            "\(scopeLabel) \(summary.corpusCount)",
            "\(wordZText("词数", "tokens", mode: languageMode)) \(summary.tokenCount)",
            "\(wordZText("不同词项", "types", mode: languageMode)) \(summary.typeCount)"
        ].joined(separator: " · ")
    }

    func buildConfigurationSummary(
        configuration: KeywordSuiteConfiguration,
        languageMode: AppLanguageMode
    ) -> String {
        [
            "\(wordZText("单位", "Unit", mode: languageMode)): \(configuration.unit.title(in: languageMode))",
            "\(wordZText("方向", "Direction", mode: languageMode)): \(configuration.direction.title(in: languageMode))",
            "\(wordZText("显著性算法", "Statistic", mode: languageMode)): \(configuration.statistic.title(in: languageMode))",
            "\(wordZText("语言预设", "Language Preset", mode: languageMode)): \(configuration.tokenFilters.languagePreset.title(in: languageMode))",
            "\(wordZText("目标最小词频", "Min Focus", mode: languageMode)): \(configuration.thresholds.minFocusFreq)",
            "\(wordZText("参照最小词频", "Min Reference", mode: languageMode)): \(configuration.thresholds.minReferenceFreq)",
            "\(wordZText("合计最小词频", "Min Combined", mode: languageMode)): \(configuration.thresholds.minCombinedFreq)",
            "\(wordZText("显著性上限", "Max p", mode: languageMode)): \(String(format: "%.3f", configuration.thresholds.maxPValue))",
            "\(wordZText("差异强度下限", "Min Difference Strength", mode: languageMode)): \(String(format: "%.2f", configuration.thresholds.minAbsLogRatio))",
            configuration.tokenFilters.stopwordFilter.summaryText(in: languageMode)
        ].joined(separator: " · ")
    }

    func buildMethodSummary(
        activeTab: KeywordSuiteTab,
        listMode: KeywordSavedListViewMode,
        configuration: KeywordSuiteConfiguration,
        annotationState: WorkspaceAnnotationState,
        focusSummary: String,
        referenceSummary: String,
        primarySavedList: KeywordSavedList?,
        secondarySavedList: KeywordSavedList?,
        hasPendingRunChanges: Bool,
        languageMode: AppLanguageMode
    ) -> String {
        let baseSummary: String
        switch activeTab {
        case .words:
            baseSummary = wordZText(
                "词页会比较目标语料和参照语料，找出更能代表目标语料的单词，并给出显著性、差异强度和覆盖数。",
                "The Words tab compares target and reference corpora, then reports significance, difference strength, and coverage for single-word items.",
                mode: languageMode
            )
        case .terms:
            baseSummary = wordZText(
                "术语页会从句内 2-5 gram 候选中筛出更像术语的多词表达，再按当前显著性算法排序。",
                "The Terms tab filters sentence-bounded 2-5 gram candidates through lexical rules before ranking them by the current statistic.",
                mode: languageMode
            )
        case .ngrams:
            baseSummary = wordZText(
                "N-grams 页显示句内连续 2-5 gram 片段的关键词结果，不跨句拼接。",
                "The N-grams tab ranks sentence-bounded contiguous 2-5 gram candidates without crossing sentence boundaries.",
                mode: languageMode
            )
        case .lists:
            switch listMode {
            case .pairwiseDiff:
                if let primarySavedList, let secondarySavedList {
                    baseSummary = wordZText(
                        "当前正在比较 \(primarySavedList.name) 和 \(secondarySavedList.name) 两份已保存词表，展示共有项、单边项和差异强度变化。",
                        "This view compares saved lists \(primarySavedList.name) and \(secondarySavedList.name), showing shared items, one-sided items, and difference strength changes.",
                        mode: languageMode
                    )
                } else {
                    baseSummary = wordZText(
                        "词表对比会比较两份已保存词表的共有项、缺失项和排序变化。",
                        "Pairwise Diff compares two saved lists for shared items, missing items, and ranking changes.",
                        mode: languageMode
                    )
                }
            case .keywordDatabase:
                baseSummary = wordZText(
                    "关键词汇总会聚合多份已保存词表，按覆盖数和平均差异强度追踪反复出现的关键词。",
                    "Keyword summary aggregates saved lists by coverage and average difference strength to surface recurring keywords.",
                    mode: languageMode
                )
            }
        }

        let scopeSummary = [
            "\(wordZText("目标语料", "Focus", mode: languageMode)): \(focusSummary)",
            "\(wordZText("参照语料", "Reference", mode: languageMode)): \(referenceSummary)",
            annotationState.summary(in: languageMode)
        ].joined(separator: " ")

        guard hasPendingRunChanges, activeTab != .lists else {
            return baseSummary + " " + scopeSummary
        }
        return baseSummary + " " + scopeSummary + " " + wordZText(
            "输入参数已修改，当前表格仍基于上次运行结果。",
            "Inputs changed, but the current table still reflects the last completed run.",
            mode: languageMode
        )
    }

    func buildMethodNotes(
        activeTab: KeywordSuiteTab,
        listMode: KeywordSavedListViewMode,
        configuration: KeywordSuiteConfiguration,
        languageMode: AppLanguageMode
    ) -> [String] {
        switch activeTab {
        case .words, .terms, .ngrams:
            return [
                wordZText(
                    "方向设为“双向”时，会同时保留目标语料更突出和参照语料更突出的词。",
                    "With Direction = Both, both positive and negative keywords are retained and explicitly marked in the Direction column.",
                    mode: languageMode
                ),
                wordZText(
                    "标准频率统一按每百万词计算，方便不同规模语料直接比较。",
                    "Normalized frequencies are reported per million words so corpora of different sizes stay comparable.",
                    mode: languageMode
                ),
                wordZText(
                    "停用词、脚本和词类筛选会在候选生成前生效，因此会同时影响频次、覆盖和示例。",
                    "Stopword, script, and lexical-class filters are applied before candidate generation, so they affect counts, ranges, and examples together.",
                    mode: languageMode
                ),
                configuration.thresholds.minCombinedFreq > 1
                    ? wordZText(
                        "当前启用了合计最小词频，用来降低偶发候选的噪声。",
                        "A combined-frequency threshold is active to reduce accidental low-frequency noise.",
                        mode: languageMode
                    )
                    : wordZText(
                        "当前合计最小词频较低，解释低频项时要更谨慎。",
                        "The combined-frequency threshold is low, so interpret rare items more cautiously.",
                        mode: languageMode
                    )
            ]
        case .lists:
            switch listMode {
            case .pairwiseDiff:
                return [
                    wordZText(
                        "仅左侧 / 仅右侧表示该词只出现在其中一份保存词表。",
                        "Only Left / Only Right indicates that an item appears in only one of the two saved lists.",
                        mode: languageMode
                    ),
                    wordZText(
                        "差异强度差 = 左侧词表差异强度 - 右侧词表差异强度。",
                        "Difference strength delta is calculated as left list strength minus right list strength.",
                        mode: languageMode
                    )
                ]
            case .keywordDatabase:
                return [
                    wordZText(
                        "覆盖词表数表示一个词项出现于多少份已保存词表。",
                        "Coverage Count shows how many saved lists contain the item.",
                        mode: languageMode
                    ),
                    wordZText(
                        "平均显著性使用各列表中绝对显著性的平均值，避免正负方向互相抵消。",
                        "Mean significance uses the average absolute significance across lists to avoid positive/negative cancellation.",
                        mode: languageMode
                    )
                ]
            }
        }
    }

    func analysisTitle(
        activeTab: KeywordSuiteTab,
        listMode: KeywordSavedListViewMode,
        languageMode: AppLanguageMode
    ) -> String {
        switch activeTab {
        case .words:
            return wordZText("关键词计算 / 词", "Keyword Analysis / Words", mode: languageMode)
        case .terms:
            return wordZText("关键词计算 / 术语", "Keyword Analysis / Terms", mode: languageMode)
        case .ngrams:
            return wordZText("关键词计算 / N-grams", "Keyword Analysis / N-grams", mode: languageMode)
        case .lists:
            return listMode.title(in: languageMode)
        }
    }

    func diffStatusTitle(
        _ status: KeywordSavedListDiffRow.DiffStatus,
        mode: AppLanguageMode
    ) -> String {
        switch status {
        case .onlyLeft:
            return wordZText("仅左侧", "Only Left", mode: mode)
        case .onlyRight:
            return wordZText("仅右侧", "Only Right", mode: mode)
        case .shared:
            return wordZText("共有", "Shared", mode: mode)
        }
    }

    func compareItems(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
}
