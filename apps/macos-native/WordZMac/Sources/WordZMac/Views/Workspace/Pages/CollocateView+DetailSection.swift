import SwiftUI

extension CollocateView {
    func collocateSelectedRowSection(
        _ selectedRow: CollocateSceneRow,
        focusMetric: CollocateAssociationMetric
    ) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(selectedRow.word)
                        .font(.headline)
                    Text("LogDice \(selectedRow.logDiceText) · MI \(selectedRow.mutualInformationText) · T-Score \(selectedRow.tScoreText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Text("\(t("共现率", "Rate")) \(selectedRow.rateText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack(spacing: 16) {
                    detailMetric(title: "FreqLR", value: selectedRow.totalText)
                    detailMetric(title: "FreqL", value: selectedRow.leftText)
                    detailMetric(title: "FreqR", value: selectedRow.rightText)
                    detailMetric(title: t("搭配词词频", "Collocate Freq"), value: selectedRow.wordFreqText)
                    detailMetric(title: t("节点词词频", "Keyword Freq"), value: selectedRow.keywordFreqText)
                }

                Text(metricInterpretation(for: focusMetric))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
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

    var collocateEmptyState: some View {
        WorkbenchEmptyStateCard(
            title: t("尚未生成搭配词结果", "No collocate results yet"),
            systemImage: "point.3.filled.connected.trianglepath.dotted",
            message: t("输入一个节点词，选择窗口范围，再运行搭配分析。WordZ 会同时提供频次、LogDice、MI 和 T-Score，方便课堂演示和研究判断。", "Enter a node word, choose the window, and run the collocate analysis. WordZ will report raw frequency, LogDice, MI, and T-Score for teaching and research workflows."),
            suggestions: [
                t("想先做稳定探索时，用“平衡探索”预设。", "Use the Balanced preset when you want a stable first-pass exploration."),
                t("如果更关心专属性强的低频搭配，可以再切到“严格关联”。", "Switch to the Strict preset when you want to emphasize exclusive low-frequency associations.")
            ]
        ) {
            Text(t("常见做法是先看 LogDice 或 T-Score，再检查原始频次。", "A common workflow is to inspect LogDice or T-Score first, then check raw frequency."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    func detailMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }

    func metricInterpretation(for metric: CollocateAssociationMetric) -> String {
        switch metric {
        case .logDice:
            return t("当前重点指标是 LogDice。它通常更适合作为默认排序，因为对高频项更稳健，不会像 MI 那样偏爱极低频词。", "The current focus metric is LogDice. It is usually the best default ranking because it is more stable for higher-frequency items and less biased toward extremely rare words than MI.")
        case .mutualInformation:
            return t("当前重点指标是 MI。它更擅长发现专属性强的稀有搭配，但你需要结合原始频次一起判断。", "The current focus metric is MI. It is good at surfacing exclusive rare collocates, but it should be interpreted together with raw frequency.")
        case .tScore:
            return t("当前重点指标是 T-Score。它更偏向频次高且反复出现的稳定搭配。", "The current focus metric is T-Score. It favors more frequent and repeatedly attested stable collocates.")
        case .rate:
            return t("当前重点指标是共现率。它适合快速浏览节点词周边最常见的搭配。", "The current focus metric is Rate. It is useful for quickly browsing the most common neighbors around the keyword.")
        case .frequency:
            return t("当前重点指标是共现频次。它适合做粗排，但最好再结合关联度指标一起解释。", "The current focus metric is raw co-occurrence frequency. It works well for coarse ranking, but it is best interpreted together with association measures.")
        }
    }
}
