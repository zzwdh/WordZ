import SwiftUI

struct ChiSquareView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: ChiSquarePageViewModel
    let onAction: (ChiSquarePageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(title: t("卡方", "Chi-Square"), subtitle: t("对 2×2 列联表做卡方检验并查看期望频数", "Run chi-square on a 2×2 contingency table and inspect expected frequencies")) {
                HStack(spacing: 10) {
                    Button(t("计算卡方", "Run Chi-Square")) { onAction(.run) }
                        .buttonStyle(.borderedProminent)
                    Button(t("重置", "Reset")) { onAction(.reset) }
                }
            }

            WorkbenchToolbarSection {
                HStack(spacing: 12) {
                    labeledField("A", text: $viewModel.a)
                    labeledField("B", text: $viewModel.b)
                    labeledField("C", text: $viewModel.c)
                    labeledField("D", text: $viewModel.d)
                    Toggle(t("Yates 校正", "Yates Correction"), isOn: $viewModel.useYates)
                        .toggleStyle(.switch)
                        .frame(width: 160)
                }
            }

            if let scene = viewModel.scene {
                WorkbenchToolbarSection {
                    Text(scene.summary)
                        .font(.headline)

                    HStack(spacing: 12) {
                        ForEach(scene.metrics) { metric in
                            WorkbenchMetricCard(title: metric.title, value: metric.value)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("观察频数", "Observed Frequencies"))
                            .font(.headline)
                        matrixGrid(rows: scene.observedRows)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("期望频数", "Expected Frequencies"))
                            .font(.headline)
                        matrixGrid(rows: scene.expectedRows)
                    }

                    if !scene.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("提示", "Notes"))
                                .font(.headline)
                            ForEach(scene.warnings, id: \.self) { warning in
                                Text("• \(warning)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    t("尚未生成卡方结果", "No chi-square results yet"),
                    systemImage: "tablecells.badge.ellipsis",
                    description: Text(t("输入 2×2 列联表的四个频数后即可运行卡方检验。", "Enter the four frequencies of a 2×2 contingency table to run chi-square."))
                )
            }
        }
        .padding(20)
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
        }
    }

    private func matrixGrid(rows: [ChiSquareMatrixSceneRow]) -> some View {
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

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private extension Array where Element == String {
    subscript(safe index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
