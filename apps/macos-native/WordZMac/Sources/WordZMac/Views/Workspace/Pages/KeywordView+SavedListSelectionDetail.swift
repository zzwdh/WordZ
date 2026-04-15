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
            "\(selectedRow.diffStatusText) · \(t("左侧排名", "Left Rank")) \(selectedRow.leftRankText) · \(t("右侧排名", "Right Rank")) \(selectedRow.rightRankText) · ΔLR \(selectedRow.logRatioDeltaText)"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }

    @ViewBuilder
    func keywordDatabaseDetail(_ selectedRow: KeywordSceneRow) -> some View {
        Text(
            "\(t("覆盖", "Coverage")) \(selectedRow.coverageCountText) · Rate \(selectedRow.coverageRateText) · Mean Keyness \(selectedRow.meanKeynessText) · Mean |LR| \(selectedRow.meanAbsLogRatioText)"
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
