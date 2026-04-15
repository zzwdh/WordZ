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

                HStack(spacing: 12) {
                    Button(t("在 KWIC 中打开", "Open in KWIC")) {
                        onAction(.openKWIC)
                    }
                    Button(t("打开搭配分析", "Open Collocate")) {
                        onAction(.openCollocate)
                    }
                    Button(t("保存语料集", "Save Corpus Set")) {
                        onAction(.saveCorpusSet)
                    }
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
}
