import SwiftUI

extension TopicsView {
    var toolbarSection: some View {
        WorkbenchSearchToolbarSection(
            searchOptions: $viewModel.searchOptions,
            stopwordFilter: $viewModel.stopwordFilter,
            isEditingStopwords: $viewModel.isEditingStopwords
        ) {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            queryField
                            minTopicSizeField
                            keywordDisplayCountField
                            outlierToggle
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            queryField
                            HStack(spacing: 12) {
                                minTopicSizeField
                                keywordDisplayCountField
                                outlierToggle
                                Spacer(minLength: 0)
                            }
                        }
                    }
                } actions: {
                    HStack(spacing: 8) {
                        topicsRunButton
                        if viewModel.canAnalyzeVisibleTopicsInSentiment {
                            Button(t("情感分析可见主题", "Analyze Visible Topics in Sentiment")) {
                                onAction(.openSentiment(.visibleTopics))
                            }
                            .buttonStyle(.bordered)
                            .disabled(isBusy)
                        }
                    }
                }

                Text(topicsControlSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let crossAnalysisSummary = viewModel.crossAnalysisSummary {
                    Text(crossAnalysisSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

    var keywordDisplayCountField: some View {
        TextField(t("关键词数", "Keywords"), text: $viewModel.keywordDisplayCount)
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
    }

    var outlierToggle: some View {
        Toggle(t("显示离群点", "Show Outliers"), isOn: $viewModel.includeOutliers)
            .toggleStyle(.checkbox)
    }

    var topicsRunButton: some View {
        Button(viewModel.crossAnalysisSummary == nil ? t("开始建模", "Run Topics") : t("运行 Compare x Topics", "Run Compare x Topics")) {
            onAction(.run)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isBusy)
    }

    var topicsControlSummary: String {
        "\(t("最小主题", "Min Topic")) \(viewModel.minTopicSizeValue) · \(t("关键词", "Keywords")) \(viewModel.keywordDisplayCountValue) · \(viewModel.includeOutliers ? t("显示离群点", "Show outliers") : t("隐藏离群点", "Hide outliers"))"
    }

    func providerLabel(for scene: TopicsSceneModel) -> String {
        if scene.usesFallbackProvider {
            return t("稳定兜底", "Stable Fallback")
        }
        switch scene.modelProvider {
        case "bundled-local-embedding":
            return t("内置主题向量", "Bundled Topic Embedding")
        case "bundled-lexical-embedding":
            return t("内置主题向量", "Bundled Topic Embedding")
        case "system-sentence-embedding":
            return t("系统句向量", "System Embedding")
        case "hashed-fallback":
            return t("稳定兜底", "Stable Fallback")
        default:
            return scene.modelProvider
        }
    }
}
