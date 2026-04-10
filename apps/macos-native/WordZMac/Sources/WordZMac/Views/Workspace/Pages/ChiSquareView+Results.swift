import SwiftUI

extension ChiSquareView {
    func summarySection(_ scene: ChiSquareSceneModel) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        conclusionBlock(scene)
                        Spacer(minLength: 0)
                        methodBadge(scene.methodLabel)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        conclusionBlock(scene)
                        methodBadge(scene.methodLabel)
                    }
                }

                Text(scene.effectSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func conclusionBlock(_ scene: ChiSquareSceneModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: conclusionSymbolName(for: scene.tone))
                .font(.title3.weight(.semibold))
                .foregroundStyle(conclusionTint(for: scene.tone))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(scene.summary)
                    .font(.title3.weight(.semibold))
                Text(scene.summaryDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func methodBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.12), in: Capsule())
    }

    func matrixSection(title: String, description: String, rows: [ChiSquareMatrixSceneRow]) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                matrixGrid(rows: rows)
            }
        }
    }

    func totalsSection(_ scene: ChiSquareSceneModel) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("样本概览", "Sample Overview"))
                    .font(.headline)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        detailStack(
                            title: t("行合计", "Row Totals"),
                            items: scene.rowTotals
                        )
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        detailStack(
                            title: t("列合计", "Column Totals"),
                            items: scene.columnTotals
                        )
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        detailStack(
                            title: t("行合计", "Row Totals"),
                            items: scene.rowTotals
                        )
                        detailStack(
                            title: t("列合计", "Column Totals"),
                            items: scene.columnTotals
                        )
                    }
                }
            }
        }
    }

    func detailStack(title: String, items: [ChiSquareDetailSceneItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Text(item.title)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(item.value)
                        .monospacedDigit()
                }
                .font(.callout)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func warningsSection(_ warnings: [String]) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("结果提示", "Result Notes"))
                    .font(.headline)
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func matrixGrid(rows: [ChiSquareMatrixSceneRow]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("")
                Text(t("目标词", "Target")).font(.caption.weight(.semibold))
                Text(t("非目标词", "Non-target")).font(.caption.weight(.semibold))
            }
            ForEach(rows) { row in
                GridRow {
                    Text(row.label)
                        .font(.caption.weight(.semibold))
                    Text(row.values[safe: 0] ?? "—").monospacedDigit()
                    Text(row.values[safe: 1] ?? "—").monospacedDigit()
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func conclusionSymbolName(for tone: ChiSquareConclusionTone) -> String {
        switch tone {
        case .strongEvidence:
            return "checkmark.seal.fill"
        case .evidence:
            return "checkmark.circle.fill"
        case .noEvidence:
            return "info.circle.fill"
        }
    }

    func conclusionTint(for tone: ChiSquareConclusionTone) -> Color {
        switch tone {
        case .strongEvidence:
            return .green
        case .evidence:
            return .blue
        case .noEvidence:
            return .secondary
        }
    }
}

private extension Array where Element == String {
    subscript(safe index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
