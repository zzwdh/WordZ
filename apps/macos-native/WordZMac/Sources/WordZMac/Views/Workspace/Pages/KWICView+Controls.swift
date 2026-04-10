import SwiftUI

extension KWICView {
    var kwicHeaderActions: some View {
        WorkbenchPageHeaderActions(
            summary: "\(viewModel.keyword.isEmpty ? t("未设置关键词", "No keyword") : viewModel.keyword) · L\(viewModel.leftWindow) / R\(viewModel.rightWindow)",
            layout: .trailingStack
        ) {
            Button(t("开始检索", "Run KWIC")) { onAction(.run) }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
        }
    }

    var kwicInputSection: some View {
        WorkbenchSearchToolbarSection(
            searchOptions: $viewModel.searchOptions,
            stopwordFilter: $viewModel.stopwordFilter,
            isEditingStopwords: $viewModel.isEditingStopwords
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    keywordField
                    leftWindowField
                    rightWindowField
                }
                VStack(alignment: .leading, spacing: 12) {
                    keywordField
                    HStack(spacing: 12) {
                        leftWindowField
                        rightWindowField
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    var keywordField: some View {
        TextField(t("检索词", "Keyword"), text: $viewModel.keyword)
            .textFieldStyle(.roundedBorder)
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
}
