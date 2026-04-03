import SwiftUI

struct ChiSquareView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: ChiSquarePageViewModel
    let onAction: (ChiSquarePageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            inputSection

            if let scene = viewModel.scene {
                summarySection(scene)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(scene.metrics) { metric in
                        WorkbenchMetricCard(title: metric.title, value: metric.value)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        matrixSection(
                            title: t("观察频数", "Observed Frequencies"),
                            description: t("你输入的 2x2 频数表。", "The original 2x2 frequency table you entered."),
                            rows: scene.observedRows
                        )
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        matrixSection(
                            title: t("期望频数", "Expected Frequencies"),
                            description: t("在“没有差异”假设下模型应看到的频数。", "The frequencies expected under the no-difference hypothesis."),
                            rows: scene.expectedRows
                        )
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        matrixSection(
                            title: t("观察频数", "Observed Frequencies"),
                            description: t("你输入的 2x2 频数表。", "The original 2x2 frequency table you entered."),
                            rows: scene.observedRows
                        )
                        matrixSection(
                            title: t("期望频数", "Expected Frequencies"),
                            description: t("在“没有差异”假设下模型应看到的频数。", "The frequencies expected under the no-difference hypothesis."),
                            rows: scene.expectedRows
                        )
                    }
                }

                totalsSection(scene)

                if !scene.warnings.isEmpty {
                    warningsSection(scene.warnings)
                }
            } else {
                WorkbenchSectionCard {
                    ContentUnavailableView(
                        t("尚未生成卡方结果", "No chi-square results yet"),
                        systemImage: "tablecells.badge.ellipsis",
                        description: Text(
                            t(
                                "先在上方填入 2x2 列联表，再点击“计算卡方”。",
                                "Fill the 2x2 contingency table above, then click Run Chi-Square."
                            )
                        )
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var inputSection: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("2x2 列联表输入", "2x2 Contingency Table"))
                    .font(.headline)

                Text(
                    t(
                        "左列填目标词频数，右列填非目标词频数；上行为语料 1，下行为语料 2。",
                        "Put target-term counts in the left column and non-target counts on the right; corpus 1 goes on the first row and corpus 2 on the second."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                contingencyInputGrid

                if hasInvalidInput {
                    Text(t("请将 A、B、C、D 都填写为大于等于 0 的整数。", "A, B, C, and D must all be integers greater than or equal to 0."))
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        correctionToggle
                        Spacer(minLength: 0)
                        resetButton
                        runButton
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        correctionToggle
                        HStack(spacing: 12) {
                            resetButton
                            runButton
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private var contingencyInputGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                Text("")
                gridHeader(t("目标词", "Target"))
                gridHeader(t("非目标词", "Non-target"))
                gridHeader(t("行合计", "Row Total"))
            }

            GridRow {
                rowHeader(t("语料 1", "Corpus 1"))
                numericInputCell("A", text: $viewModel.a)
                numericInputCell("B", text: $viewModel.b)
                totalPreviewCell(rowOneTotal)
            }

            GridRow {
                rowHeader(t("语料 2", "Corpus 2"))
                numericInputCell("C", text: $viewModel.c)
                numericInputCell("D", text: $viewModel.d)
                totalPreviewCell(rowTwoTotal)
            }

            Divider()
                .gridCellUnsizedAxes([.horizontal, .vertical])

            GridRow {
                rowHeader(t("列合计", "Column Total"))
                totalPreviewCell(columnOneTotal)
                totalPreviewCell(columnTwoTotal)
                totalPreviewCell(grandTotal)
            }
        }
    }

    private var correctionToggle: some View {
        Toggle(t("启用 Yates 连续性校正", "Use Yates Correction"), isOn: $viewModel.useYates)
            .toggleStyle(.switch)
    }

    private var resetButton: some View {
        Button(t("重置", "Reset")) { onAction(.reset) }
    }

    private var runButton: some View {
        Button(t("计算卡方", "Run Chi-Square")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
    }

    private func summarySection(_ scene: ChiSquareSceneModel) -> some View {
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

    private func conclusionBlock(_ scene: ChiSquareSceneModel) -> some View {
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

    private func methodBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.12), in: Capsule())
    }

    private func matrixSection(title: String, description: String, rows: [ChiSquareMatrixSceneRow]) -> some View {
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

    private func totalsSection(_ scene: ChiSquareSceneModel) -> some View {
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

    private func detailStack(title: String, items: [ChiSquareDetailSceneItem]) -> some View {
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

    private func warningsSection(_ warnings: [String]) -> some View {
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

    private func gridHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 80, alignment: .leading)
    }

    private func numericInputCell(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 96)
        }
        .padding(10)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func totalPreviewCell(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "—")
            .font(.body.monospacedDigit())
            .frame(minWidth: 72, alignment: .trailing)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var parsedA: Int? { parsedCount(viewModel.a) }
    private var parsedB: Int? { parsedCount(viewModel.b) }
    private var parsedC: Int? { parsedCount(viewModel.c) }
    private var parsedD: Int? { parsedCount(viewModel.d) }

    private var hasInvalidInput: Bool {
        invalidInput(viewModel.a) || invalidInput(viewModel.b) || invalidInput(viewModel.c) || invalidInput(viewModel.d)
    }

    private var rowOneTotal: Int? { sum(parsedA, parsedB) }
    private var rowTwoTotal: Int? { sum(parsedC, parsedD) }
    private var columnOneTotal: Int? { sum(parsedA, parsedC) }
    private var columnTwoTotal: Int? { sum(parsedB, parsedD) }
    private var grandTotal: Int? { sum(rowOneTotal, rowTwoTotal) }

    private func parsedCount(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), value >= 0 else {
            return nil
        }
        return value
    }

    private func invalidInput(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return parsedCount(trimmed) == nil
    }

    private func sum(_ lhs: Int?, _ rhs: Int?) -> Int? {
        guard let lhs, let rhs else { return nil }
        return lhs + rhs
    }

    private func conclusionSymbolName(for tone: ChiSquareConclusionTone) -> String {
        switch tone {
        case .strongEvidence:
            return "checkmark.seal.fill"
        case .evidence:
            return "checkmark.circle.fill"
        case .noEvidence:
            return "info.circle.fill"
        }
    }

    private func conclusionTint(for tone: ChiSquareConclusionTone) -> Color {
        switch tone {
        case .strongEvidence:
            return .green
        case .evidence:
            return .blue
        case .noEvidence:
            return .secondary
        }
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
