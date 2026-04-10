import SwiftUI

extension ChiSquareView {
    var inputSection: some View {
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

    var contingencyInputGrid: some View {
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

    var correctionToggle: some View {
        Toggle(t("启用 Yates 连续性校正", "Use Yates Correction"), isOn: $viewModel.useYates)
            .toggleStyle(.switch)
    }

    var resetButton: some View {
        Button(t("重置", "Reset")) { onAction(.reset) }
    }

    var runButton: some View {
        Button(t("计算卡方", "Run Chi-Square")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
    }

    func gridHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func rowHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 80, alignment: .leading)
    }

    func numericInputCell(_ label: String, text: Binding<String>) -> some View {
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

    func totalPreviewCell(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "—")
            .font(.body.monospacedDigit())
            .frame(minWidth: 72, alignment: .trailing)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    var parsedA: Int? { parsedCount(viewModel.a) }
    var parsedB: Int? { parsedCount(viewModel.b) }
    var parsedC: Int? { parsedCount(viewModel.c) }
    var parsedD: Int? { parsedCount(viewModel.d) }

    var hasInvalidInput: Bool {
        invalidInput(viewModel.a) || invalidInput(viewModel.b) || invalidInput(viewModel.c) || invalidInput(viewModel.d)
    }

    var rowOneTotal: Int? { sum(parsedA, parsedB) }
    var rowTwoTotal: Int? { sum(parsedC, parsedD) }
    var columnOneTotal: Int? { sum(parsedA, parsedC) }
    var columnTwoTotal: Int? { sum(parsedB, parsedD) }
    var grandTotal: Int? { sum(rowOneTotal, rowTwoTotal) }

    func parsedCount(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), value >= 0 else {
            return nil
        }
        return value
    }

    func invalidInput(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return parsedCount(trimmed) == nil
    }

    func sum(_ lhs: Int?, _ rhs: Int?) -> Int? {
        guard let lhs, let rhs else { return nil }
        return lhs + rhs
    }
}
