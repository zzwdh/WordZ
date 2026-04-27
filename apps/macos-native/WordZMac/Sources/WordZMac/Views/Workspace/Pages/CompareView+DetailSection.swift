import SwiftUI

extension CompareView {
    func compareSelectedRowSection(_ selectedRow: CompareSceneRow) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(selectedRow.word)
                        .font(.headline)
                    Text("Keyness \(selectedRow.keynessText) · Log Ratio \(selectedRow.effectText) · p \(selectedRow.pValueText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Text("\(t("主导语料", "Dominant")): \(selectedRow.dominantCorpus)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    compareDetailMetric(t("覆盖", "Spread"), value: selectedRow.spreadText)
                    compareDetailMetric(t("总频", "Total"), value: selectedRow.totalText)
                    compareDetailMetric(t("差异", "Range"), value: selectedRow.rangeText)
                    compareDetailMetric(t("参考标准频次", "Reference Norm Freq"), value: selectedRow.referenceNormFreqText)
                }

                HStack(spacing: 16) {
                    compareDetailMetric(t("参考语料", "Reference Corpus"), value: selectedRow.referenceLabelText)
                    compareDetailMetric(t("主导语料", "Dominant Corpus"), value: selectedRow.dominantCorpus)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(t("完整分布", "Full Distribution"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(selectedRow.distributionText)
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 54, maxHeight: 96)
                }

                if let sentimentSummary = viewModel.scene?.sentimentSummary,
                   sentimentSummary.focusTerm == selectedRow.word {
                    compareSentimentSummaryCard(sentimentSummary)
                }

                if let sentimentExplainer = viewModel.scene?.sentimentExplainer,
                   sentimentExplainer.focusTerm == selectedRow.word {
                    compareSentimentExplainerCard(sentimentExplainer)
                }

                if let topicsSummary = viewModel.scene?.topicsSummary,
                   topicsSummary.focusTerm == selectedRow.word {
                    compareTopicsSummaryCard(topicsSummary)
                }

                HStack(spacing: 12) {
                    Button(t("在 KWIC 中打开", "Open in KWIC")) {
                        onAction(.openKWIC)
                    }
                    Button(t("打开搭配分析", "Open Collocate")) {
                        onAction(.openCollocate)
                    }
                    Button(t("打开情感分析", "Open Sentiment")) {
                        onAction(.openSentiment)
                    }
                    Button(t("打开主题分析", "Open Topics")) {
                        onAction(.openTopics)
                    }
                    .disabled(!viewModel.canOpenTopicsCrossAnalysis || isBusy)
                    Button(t("转到 Keyword Suite", "Analyze in Keyword Suite")) {
                        onAction(.analyzeInKeywordSuite)
                    }
                    Menu(t("研究导出", "Research Export")) {
                        Button("Copy Current") {
                            onAction(.copyCurrent(.summary))
                        }
                        Button("Copy Visible") {
                            onAction(.copyVisible(.summary))
                        }
                        Divider()
                        Button("Export Current") {
                            onAction(.exportCurrent(.summary))
                        }
                        Button("Export Visible") {
                            onAction(.exportVisible(.summary))
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    var compareEmptyState: some View {
        WorkbenchEmptyStateCard(
            title: t("尚未生成对比结果", "No comparison results yet"),
            systemImage: "square.2.layers.3d.top.filled",
            message: t("先选择至少两条语料，再运行对比。系统会用 Keyness 和 Log Ratio 帮你判断哪些词在哪个语料中更突出。", "Select at least two corpora and run Compare. WordZ will use Keyness and Log Ratio to show which words are most distinctive in each corpus."),
            suggestions: [
                t("优先选择体裁或来源差异明显的语料，结果更容易解释。", "Start with corpora that differ clearly by genre or source so the contrast is easier to interpret."),
                t("需要做课堂演示时，先保留默认搜索设置，再逐步加入停用词过滤。", "For teaching demos, keep the default search settings first, then add stopword filtering step by step.")
            ]
        ) {
            Text(t("至少选择 2 条语料后才可运行。", "Run becomes available after at least two corpora are selected."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    func compareSummaryCard(_ corpus: CompareCorpusSummarySceneItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(corpus.title)
                .font(.headline)
            Text(corpus.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Token \(corpus.tokenCountText) · Type \(corpus.typeCountText)")
                .font(.caption)
                .monospacedDigit()
            Text("TTR \(corpus.ttrText) · STTR \(corpus.sttrText)")
                .font(.caption)
                .monospacedDigit()
            Text("Top \(corpus.topWordText)")
                .font(.caption)
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(WordZTheme.primarySurfaceSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func compareDetailMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
    }

    func compareSentimentSummaryCard(_ summary: CompareSentimentSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary.headline)
                .font(.subheadline.weight(.semibold))
            Text(summary.scopeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(summary.targetDistribution)
                .font(.caption.monospacedDigit())
            if let referenceDistribution = summary.referenceDistribution {
                Text(referenceDistribution)
                    .font(.caption.monospacedDigit())
            }
            Text(summary.note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WordZTheme.primarySurfaceSoft)
        )
    }

    func compareSentimentExplainerCard(_ explainer: CompareSentimentExplainer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Sentiment Explainer", "Sentiment Explainer"))
                .font(.subheadline.weight(.semibold))

            Text(explainer.scopeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                compareSentimentSummaryMetric(
                    explainer.targetSummary.title,
                    value: compareDistributionText(explainer.targetSummary)
                )
                if let referenceSummary = explainer.referenceSummary {
                    compareSentimentSummaryMetric(
                        referenceSummary.title,
                        value: compareDistributionText(referenceSummary)
                    )
                }
            }

            HStack(spacing: 12) {
                compareSentimentSummaryMetric(
                    t("分布差值", "Distribution Delta"),
                    value: "+\(comparePointsText(explainer.positiveDeltaPoints)) · =\(comparePointsText(explainer.neutralDeltaPoints)) · -\(comparePointsText(explainer.negativeDeltaPoints))"
                )
                compareSentimentSummaryMetric(
                    t("平均净分差值", "Average Net Delta"),
                    value: String(format: "%.3f", explainer.averageNetDelta)
                )
            }

            compareSentimentReviewImpactRow(
                title: t("目标侧审校", "Target Review"),
                impact: explainer.targetReviewImpact
            )

            if let referenceImpact = explainer.referenceReviewImpact {
                compareSentimentReviewImpactRow(
                    title: t("参考侧审校", "Reference Review"),
                    impact: referenceImpact
                )
            }

            if !explainer.targetTopDrivers.isEmpty || !explainer.referenceTopDrivers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("驱动线索", "Driver Cues"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if !explainer.targetTopDrivers.isEmpty {
                        compareDriverList(
                            title: t("目标侧", "Target"),
                            drivers: explainer.targetTopDrivers
                        )
                    }
                    if !explainer.referenceTopDrivers.isEmpty {
                        compareDriverList(
                            title: t("参考侧", "Reference"),
                            drivers: explainer.referenceTopDrivers
                        )
                    }
                }
            }

            if !explainer.targetExemplars.isEmpty || !explainer.referenceExemplars.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("代表样例", "Exemplars"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if !explainer.targetExemplars.isEmpty {
                        compareExemplarList(
                            title: t("目标侧", "Target"),
                            exemplars: explainer.targetExemplars
                        )
                    }
                    if !explainer.referenceExemplars.isEmpty {
                        compareExemplarList(
                            title: t("参考侧", "Reference"),
                            exemplars: explainer.referenceExemplars
                        )
                    }
                }
            }

            HStack(spacing: 12) {
                Button(t("打开情感分析", "Open in Sentiment")) {
                    onAction(.openSentiment)
                }
                .disabled(isBusy)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WordZTheme.primarySurfaceSoft)
        )
    }

    func compareSentimentSummaryMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func compareSentimentReviewImpactRow(
        title: String,
        impact: SentimentReviewImpactSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(
                "\(t("已审阅", "Reviewed")) \(impact.reviewedCount) · " +
                "\(t("确认原判", "Confirmed")) \(impact.confirmedRawCount) · " +
                "\(t("人工改标", "Overridden")) \(impact.overriddenCount) · " +
                "\(t("生效改动", "Changed")) \(impact.changedCount)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    func compareDriverList(
        title: String,
        drivers: [SentimentDriverCueSummary]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
            ForEach(drivers) { driver in
                Text(compareDriverLine(driver))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func compareExemplarList(
        title: String,
        exemplars: [SentimentExemplarRowSummary]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
            ForEach(exemplars) { exemplar in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(exemplar.effectiveLabel.title(in: languageMode))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06), in: Capsule())
                        if exemplar.reviewStatus == .overridden {
                            Text(t("人工改标", "Manual Override"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Text(exemplar.sourceTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(exemplar.text)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button(t("在情感分析中打开", "Open in Sentiment")) {
                            onAction(.openSentimentExemplar(exemplar.id))
                        }
                        .buttonStyle(.borderless)
                        .disabled(isBusy)

                        Button(t("打开原文视图", "Open Source Reader")) {
                            onAction(.openSentimentSourceReader(exemplar.id))
                        }
                        .buttonStyle(.borderless)
                        .disabled(isBusy || !exemplar.canOpenSourceReader)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    func compareDistributionText(_ summary: SentimentAggregateSummary) -> String {
        "+\(summary.positiveCount) / =\(summary.neutralCount) / -\(summary.negativeCount)"
    }

    func comparePointsText(_ value: Double) -> String {
        String(format: "%.1fpp", value)
    }

    func compareDriverLine(_ driver: SentimentDriverCueSummary) -> String {
        "\(driver.cue) · \(driver.direction.title(in: languageMode)) · \(String(format: "%.2f", driver.totalWeight)) · \(t("规则", "Rule")) \(driver.primaryRuleTag)"
    }
}
