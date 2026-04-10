import SwiftUI

struct TopicsView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: TopicsPageViewModel
    let isBusy: Bool
    let onAction: (TopicsPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("主题", "Topics")
        ) {
            WorkbenchPageHeaderActions(
                summary: "\(t("最小主题", "Min Topic")) \(viewModel.minTopicSize) · \(viewModel.includeOutliers ? t("显示离群点", "Show outliers") : t("隐藏离群点", "Hide outliers"))",
                layout: .inline
            ) {
                Button(t("开始建模", "Run Topics")) {
                    onAction(.run)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
            }
        } content: {
            toolbarSection

            if let scene = viewModel.scene {
                topicsResults(scene)
            } else {
                WorkbenchEmptyStateCard(
                    title: t("尚未生成 Topics 结果", "No Topics results yet"),
                    systemImage: "square.stack.3d.up",
                    message: t("先运行一次主题建模，WordZ 会把片段聚成主题簇，并提供关键词、代表片段和片段表格供你继续阅读。", "Run topic modeling once and WordZ will build topic clusters with keywords, representative passages, and segment tables for further reading.")
                )
            }
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
