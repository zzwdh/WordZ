import SwiftUI

extension LocatorView {
    var locatorHeaderActions: some View {
        Button(t("定位当前 KWIC", "Locate Current KWIC")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy || !viewModel.hasSource)
    }

    var locatorInputSection: some View {
        WorkbenchToolbarSection {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    leftWindowField
                    rightWindowField
                    sourceStatus
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        leftWindowField
                        rightWindowField
                    }
                    sourceStatus
                }
            }
        }
    }

    var leftWindowField: some View {
        TextField(t("左窗口", "Left Window"), text: $viewModel.leftWindow)
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
    }

    var rightWindowField: some View {
        TextField(t("右窗口", "Right Window"), text: $viewModel.rightWindow)
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
    }

    @ViewBuilder
    var sourceStatus: some View {
        if let source = viewModel.currentSource {
            Text(t("当前源：句", "Current Source: sentence") + " \(source.sentenceId + 1) · " + t("节点词", "Node") + " \(source.keyword)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        } else {
            Text(t("请先运行 KWIC。", "Run KWIC first."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
