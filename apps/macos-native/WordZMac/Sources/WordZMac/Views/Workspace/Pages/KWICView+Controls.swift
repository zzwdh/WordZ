import SwiftUI

extension KWICView {
    var kwicInputSection: some View {
        WorkbenchSearchToolbarSection(
            searchOptions: $viewModel.searchOptions,
            stopwordFilter: $viewModel.stopwordFilter,
            isEditingStopwords: $viewModel.isEditingStopwords
        ) {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
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
                } actions: {
                    HStack(spacing: 8) {
                        kwicRunButton
                        kwicSaveVisibleButton
                    }
                }

                Text(kwicControlSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var keywordField: some View {
        LexicalAutocompleteTextField(
            title: t("检索词", "Keyword"),
            text: $viewModel.keyword,
            searchOptions: viewModel.searchOptions,
            stopwordFilter: viewModel.stopwordFilter,
            controller: lexicalAutocompleteController
        )
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

    var kwicRunButton: some View {
        Button(t("开始检索", "Run KWIC")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
    }

    var kwicSaveVisibleButton: some View {
        Button(t("保存当前页", "Save Page")) { onAction(.saveVisibleHitSet) }
            .disabled(viewModel.scene?.rows.isEmpty ?? true)
            .help(t("保存当前页可见命中行，之后可在命中集中回看。", "Save the currently visible hit rows for later review."))
    }

    var kwicControlSummary: String {
        "\(viewModel.keyword.isEmpty ? t("未设置关键词", "No keyword") : viewModel.keyword) · \(t("窗口", "Window")) L\(viewModel.leftWindow) / R\(viewModel.rightWindow)"
    }
}
