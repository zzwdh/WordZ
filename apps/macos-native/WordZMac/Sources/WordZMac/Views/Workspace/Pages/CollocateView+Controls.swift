import SwiftUI

extension CollocateView {
    var collocateHeader: some View {
        WorkbenchPageHeaderActions(
            summary: "\(viewModel.keyword.isEmpty ? t("未设置节点词", "No node word") : viewModel.keyword) · L\(viewModel.leftWindow) / R\(viewModel.rightWindow) · \(viewModel.minFreq)",
            layout: .inline
        ) {
            Button(t("开始统计", "Run Collocate")) { onAction(.run) }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
        }
    }

    var collocateInputSection: some View {
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
                    minFrequencyField
                }
                VStack(alignment: .leading, spacing: 12) {
                    keywordField
                    HStack(spacing: 12) {
                        leftWindowField
                        rightWindowField
                        minFrequencyField
                        Spacer(minLength: 0)
                    }
                }
            }
        } middle: {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CollocatePreset.allCases) { preset in
                        Button(preset.title(in: languageMode)) {
                            onAction(.applyPreset(preset))
                        }
                        .buttonStyle(.bordered)
                        .help(preset.summary(in: languageMode))
                    }
                }
            }
        }
    }

    var keywordField: some View {
        TextField(t("节点词", "Node Word"), text: $viewModel.keyword)
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

    var minFrequencyField: some View {
        TextField(t("最低共现", "Min Co-occurrence"), text: $viewModel.minFreq)
            .textFieldStyle(.roundedBorder)
            .frame(width: 110)
    }

    var runButton: some View {
        Button(t("开始统计", "Run Collocate")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
    }
}
