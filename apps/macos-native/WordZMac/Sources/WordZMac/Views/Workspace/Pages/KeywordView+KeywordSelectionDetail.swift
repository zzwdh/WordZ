import SwiftUI
import WordZWorkbenchUI

extension KeywordView {
    func keywordSelectedRowSection(
        _ selectedRow: KeywordSceneRow,
        rawRow: KeywordSuiteRow
    ) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                keywordSelectedRowHeader(selectedRow)
                keywordSelectedRowMetrics(selectedRow)

                if !rawRow.example.isEmpty {
                    keywordSelectedRowExample(rawRow)
                }

                keywordSelectedRowActions(rawRow)
            }
        }
    }

    func keywordSelectedRowHeader(_ selectedRow: KeywordSceneRow) -> some View {
        HStack(spacing: 12) {
            Text(selectedRow.item)
                .font(.headline)
            Text(
                "\(selectedRow.directionText) · \(t("显著性", "Significance")) \(selectedRow.keynessText) · \(t("差异强度", "Difference Strength")) \(selectedRow.logRatioText) · \(t("p 值", "p")) \(selectedRow.pValueText)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    func keywordSelectedRowMetrics(_ selectedRow: KeywordSceneRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                keywordMetric(t("目标频次", "Focus Freq"), value: selectedRow.focusFrequencyText)
                keywordMetric(t("参照频次", "Reference Freq"), value: selectedRow.referenceFrequencyText)
                keywordMetric(t("目标标准频次", "Target Standard Frequency"), value: selectedRow.focusNormFrequencyText)
                keywordMetric(t("参照标准频次", "Reference Standard Frequency"), value: selectedRow.referenceNormFrequencyText)
            }

            HStack(spacing: 16) {
                keywordMetric(t("目标覆盖", "Focus Range"), value: selectedRow.focusRangeText)
                keywordMetric(t("参照覆盖", "Reference Range"), value: selectedRow.referenceRangeText)
            }
        }
    }

    func keywordSelectedRowExample(_ rawRow: KeywordSuiteRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("示例", "Example"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(rawRow.example)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func keywordSelectedRowActions(_ rawRow: KeywordSuiteRow) -> some View {
        HStack(spacing: 12) {
            Button(t("导出上下文", "Export Context")) {
                onAction(.exportRowContext)
            }
            .buttonStyle(.bordered)

            Button(t("查看目标语境", "Open Focus in KWIC")) {
                onAction(.openFocusKWIC)
            }
            .disabled(rawRow.focusExampleCorpusID == nil && viewModel.resolvedFocusCorpusItems().isEmpty)

            Button(t("查看参照语境", "Open Reference in KWIC")) {
                onAction(.openReferenceKWIC)
            }
            .disabled(rawRow.referenceExampleCorpusID == nil && viewModel.resolvedReferenceCorpusItems().isEmpty)

            Button(t("查看分布对比", "Open Compare Distribution")) {
                onAction(.openCompareDistribution)
            }
            .disabled(viewModel.resolvedFocusCorpusItems().isEmpty)
        }
    }
}
