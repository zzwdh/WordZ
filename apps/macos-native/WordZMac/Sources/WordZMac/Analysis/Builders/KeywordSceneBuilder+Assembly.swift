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
            "\(wordZText("tokens", "tokens", mode: languageMode)) \(summary.tokenCount)",
            "\(wordZText("types", "types", mode: languageMode)) \(summary.typeCount)"
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
            "\(wordZText("tokens", "tokens", mode: languageMode)) \(summary.tokenCount)",
            "\(wordZText("types", "types", mode: languageMode)) \(summary.typeCount)"
        ].joined(separator: " · ")
    }

    func buildConfigurationSummary(
        configuration: KeywordSuiteConfiguration,
        languageMode: AppLanguageMode
    ) -> String {
        [
            "\(wordZText("单位", "Unit", mode: languageMode)): \(configuration.unit.title(in: languageMode))",
            "\(wordZText("方向", "Direction", mode: languageMode)): \(configuration.direction.title(in: languageMode))",
            "\(wordZText("统计量", "Statistic", mode: languageMode)): \(configuration.statistic.title(in: languageMode))",
            "\(wordZText("语言预设", "Language Preset", mode: languageMode)): \(configuration.tokenFilters.languagePreset.title(in: languageMode))",
            "\(wordZText("Min Focus", "Min Focus", mode: languageMode)): \(configuration.thresholds.minFocusFreq)",
            "\(wordZText("Min Reference", "Min Reference", mode: languageMode)): \(configuration.thresholds.minReferenceFreq)",
            "\(wordZText("Min Combined", "Min Combined", mode: languageMode)): \(configuration.thresholds.minCombinedFreq)",
            "\(wordZText("Max p", "Max p", mode: languageMode)): \(String(format: "%.3f", configuration.thresholds.maxPValue))",
            "\(wordZText("Min |Log Ratio|", "Min |Log Ratio|", mode: languageMode)): \(String(format: "%.2f", configuration.thresholds.minAbsLogRatio))",
            configuration.tokenFilters.stopwordFilter.summaryText(in: languageMode)
        ].joined(separator: " · ")
    }

    func buildMethodSummary(
        activeTab: KeywordSuiteTab,
        listMode: KeywordSavedListViewMode,
        configuration: KeywordSuiteConfiguration,
        primarySavedList: KeywordSavedList?,
        secondarySavedList: KeywordSavedList?,
        hasPendingRunChanges: Bool,
        languageMode: AppLanguageMode
    ) -> String {
        let baseSummary: String
        switch activeTab {
        case .words:
            baseSummary = wordZText(
                "Words 页基于显式 Focus / Reference 比较单词级 keyness，并同时给出显著性、效应值和覆盖数。",
                "The Words tab compares explicit focus/reference corpora and reports keyness, effect size, and range for single-word items.",
                mode: languageMode
            )
        case .terms:
            baseSummary = wordZText(
                "Terms 页从句内 2-5 gram 候选中筛出符合词法规则的多词术语，再按当前统计量排序。",
                "The Terms tab filters sentence-bounded 2-5 gram candidates through lexical rules before ranking them by the current statistic.",
                mode: languageMode
            )
        case .ngrams:
            baseSummary = wordZText(
                "N-grams 页显示句内连续 2-5 gram 候选的关键词结果，不跨句拼接。",
                "The N-grams tab ranks sentence-bounded contiguous 2-5 gram candidates without crossing sentence boundaries.",
                mode: languageMode
            )
        case .lists:
            switch listMode {
            case .pairwiseDiff:
                if let primarySavedList, let secondarySavedList {
                    baseSummary = wordZText(
                        "当前正在比较 \(primarySavedList.name) 和 \(secondarySavedList.name) 两份已保存词表，展示共有项与单边项以及 log ratio 差值。",
                        "This view compares saved lists \(primarySavedList.name) and \(secondarySavedList.name), showing shared items, one-sided items, and log-ratio deltas.",
                        mode: languageMode
                    )
                } else {
                    baseSummary = wordZText(
                        "Pairwise Diff 会比较两份已保存词表的共有项、缺失项和排序变化。",
                        "Pairwise Diff compares two saved lists for shared items, missing items, and ranking changes.",
                        mode: languageMode
                    )
                }
            case .keywordDatabase:
                baseSummary = wordZText(
                    "Keyword Database 会聚合多份已保存词表，按 coverage 和平均效应值追踪反复出现的 key-key words。",
                    "Keyword Database aggregates saved lists by coverage and average effect size to surface recurring key-key words.",
                    mode: languageMode
                )
            }
        }

        guard hasPendingRunChanges, activeTab != .lists else {
            return baseSummary
        }
        return baseSummary + " " + wordZText(
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
                    "Direction = Both 时会同时保留正关键词和负关键词，方向列会明确标出来源侧。",
                    "With Direction = Both, both positive and negative keywords are retained and explicitly marked in the Direction column.",
                    mode: languageMode
                ),
                wordZText(
                    "标准频率统一按每百万词计算，方便不同规模语料直接比较。",
                    "Normalized frequencies are reported per million words so corpora of different sizes stay comparable.",
                    mode: languageMode
                ),
                wordZText(
                    "Stopword、脚本和词类筛选会在候选生成前生效，因此会同时影响频次、覆盖和示例。",
                    "Stopword, script, and lexical-class filters are applied before candidate generation, so they affect counts, ranges, and examples together.",
                    mode: languageMode
                ),
                configuration.thresholds.minCombinedFreq > 1
                    ? wordZText(
                        "当前启用了 combined frequency 阈值，用来压低偶发候选的噪声。",
                        "A combined-frequency threshold is active to reduce accidental low-frequency noise.",
                        mode: languageMode
                    )
                    : wordZText(
                        "当前 combined frequency 阈值较低，解释低频项时要更谨慎。",
                        "The combined-frequency threshold is low, so interpret rare items more cautiously.",
                        mode: languageMode
                    )
            ]
        case .lists:
            switch listMode {
            case .pairwiseDiff:
                return [
                    wordZText(
                        "Only Left / Only Right 表示该词仅出现于单边保存词表。",
                        "Only Left / Only Right indicates that an item appears in only one of the two saved lists.",
                        mode: languageMode
                    ),
                    wordZText(
                        "Log Ratio Delta = 左侧 log ratio - 右侧 log ratio。",
                        "Log Ratio Delta is calculated as left log ratio minus right log ratio.",
                        mode: languageMode
                    )
                ]
            case .keywordDatabase:
                return [
                    wordZText(
                        "Coverage Count 表示一个词项出现于多少份已保存词表。",
                        "Coverage Count shows how many saved lists contain the item.",
                        mode: languageMode
                    ),
                    wordZText(
                        "Mean Keyness 使用各列表中绝对显著性的平均值，避免正负方向互相抵消。",
                        "Mean Keyness uses the average absolute keyness across lists to avoid positive/negative cancellation.",
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
            return wordZText("关键词分析 / Words", "Keyword Suite / Words", mode: languageMode)
        case .terms:
            return wordZText("关键词分析 / Terms", "Keyword Suite / Terms", mode: languageMode)
        case .ngrams:
            return wordZText("关键词分析 / N-grams", "Keyword Suite / N-grams", mode: languageMode)
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
