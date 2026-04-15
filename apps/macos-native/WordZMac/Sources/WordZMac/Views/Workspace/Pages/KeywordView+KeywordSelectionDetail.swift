import SwiftUI

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
                "\(selectedRow.directionText) · Score \(selectedRow.keynessText) · Log Ratio \(selectedRow.logRatioText) · p \(selectedRow.pValueText)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    func keywordSelectedRowMetrics(_ selectedRow: KeywordSceneRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                keywordMetric(t("Focus 频次", "Focus Freq"), value: selectedRow.focusFrequencyText)
                keywordMetric(t("Reference 频次", "Reference Freq"), value: selectedRow.referenceFrequencyText)
                keywordMetric(t("Focus 标准频次", "Focus Norm"), value: selectedRow.focusNormFrequencyText)
                keywordMetric(t("Reference 标准频次", "Reference Norm"), value: selectedRow.referenceNormFrequencyText)
            }

            HStack(spacing: 16) {
                keywordMetric(t("Focus 覆盖", "Focus Range"), value: selectedRow.focusRangeText)
                keywordMetric(t("Reference 覆盖", "Reference Range"), value: selectedRow.referenceRangeText)
            }
        }
    }

    func keywordSelectedRowExample(_ rawRow: KeywordSuiteRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Example", "Example"))
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
            Button(t("导出 Row Context", "Export Row Context")) {
                onAction(.exportRowContext)
            }
            .buttonStyle(.bordered)

            Button(t("在 KWIC 中打开 Focus", "Open Focus in KWIC")) {
                onAction(.openFocusKWIC)
            }
            .disabled(rawRow.focusExampleCorpusID == nil && viewModel.resolvedFocusCorpusItems().isEmpty)

            Button(t("在 KWIC 中打开 Reference", "Open Reference in KWIC")) {
                onAction(.openReferenceKWIC)
            }
            .disabled(rawRow.referenceExampleCorpusID == nil && viewModel.resolvedReferenceCorpusItems().isEmpty)

            Button(t("打开 Compare 分布", "Open Compare Distribution")) {
                onAction(.openCompareDistribution)
            }
            .disabled(viewModel.resolvedFocusCorpusItems().isEmpty)
        }
    }
}
