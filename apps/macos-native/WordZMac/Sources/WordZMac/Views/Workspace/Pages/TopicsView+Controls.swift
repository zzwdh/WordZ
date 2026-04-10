import SwiftUI

extension TopicsView {
    var toolbarSection: some View {
        WorkbenchSearchToolbarSection(
            searchOptions: $viewModel.searchOptions,
            stopwordFilter: $viewModel.stopwordFilter,
            isEditingStopwords: $viewModel.isEditingStopwords
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    queryField
                    minTopicSizeField
                    outlierToggle
                }

                VStack(alignment: .leading, spacing: 12) {
                    queryField
                    HStack(spacing: 12) {
                        minTopicSizeField
                        outlierToggle
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    var queryField: some View {
        TextField(
            t("搜索主题或片段（留空显示全部）", "Search topics or segments (leave blank for all)"),
            text: $viewModel.query
        )
        .textFieldStyle(.roundedBorder)
    }

    var minTopicSizeField: some View {
        TextField(t("最小主题大小", "Min Topic Size"), text: $viewModel.minTopicSize)
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
    }

    var outlierToggle: some View {
        Toggle(t("显示离群点", "Show Outliers"), isOn: $viewModel.includeOutliers)
            .toggleStyle(.checkbox)
    }

    func providerLabel(for scene: TopicsSceneModel) -> String {
        if scene.usesFallbackProvider {
            return t("稳定兜底", "Stable Fallback")
        }
        switch scene.modelProvider {
        case "system-sentence-embedding":
            return t("系统句向量", "System Embedding")
        case "hashed-fallback":
            return t("稳定兜底", "Stable Fallback")
        default:
            return scene.modelProvider
        }
    }
}
