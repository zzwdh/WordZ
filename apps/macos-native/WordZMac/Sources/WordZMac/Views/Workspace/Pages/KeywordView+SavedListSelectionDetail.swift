import SwiftUI

extension KeywordView {
    func keywordListSelectedRowSection(_ selectedRow: KeywordSceneRow) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedRow.item)
                    .font(.headline)

                switch selectedRow.kind {
                case .pairwiseDiff:
                    keywordPairwiseDiffDetail(selectedRow)
                case .keywordDatabase:
                    keywordDatabaseDetail(selectedRow)
                case .keyword:
                    EmptyView()
                }
            }
        }
    }

    func keywordPairwiseDiffDetail(_ selectedRow: KeywordSceneRow) -> some View {
        Text(
            "\(selectedRow.diffStatusText) · \(t("左侧排名", "Left Rank")) \(selectedRow.leftRankText) · \(t("右侧排名", "Right Rank")) \(selectedRow.rightRankText) · \(t("差异强度差", "Difference Strength Delta")) \(selectedRow.logRatioDeltaText)"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }

    @ViewBuilder
    func keywordDatabaseDetail(_ selectedRow: KeywordSceneRow) -> some View {
        Text(
            "\(t("覆盖词表", "Coverage")) \(selectedRow.coverageCountText) · \(t("覆盖率", "Coverage Rate")) \(selectedRow.coverageRateText) · \(t("平均显著性", "Mean Significance")) \(selectedRow.meanKeynessText) · \(t("平均差异强度", "Mean Difference Strength")) \(selectedRow.meanAbsLogRatioText)"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        if !selectedRow.lastSeenAtText.isEmpty {
            Text("\(t("最近出现", "Last Seen")): \(selectedRow.lastSeenAtText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
