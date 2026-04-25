import SwiftUI

struct TopicsView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: TopicsPageViewModel
    let isBusy: Bool
    let onAction: (TopicsPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("主题", "Topics"),
            scrollMode: .manual
        ) {
            VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
                toolbarSection

                if let scene = viewModel.scene {
                    GeometryReader { proxy in
                        ScrollView {
                            topicsResults(
                                scene,
                                availableWidth: max(0, proxy.size.width)
                            )
                            .padding(.trailing, WordZTheme.pageScrollIndicatorGutter)
                            .padding(.bottom, WordZTheme.pagePadding)
                        }
                        .scrollIndicators(.visible)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else {
                    WorkbenchEmptyStateCard(
                        title: t("尚未生成 Topics 结果", "No Topics results yet"),
                        systemImage: "square.stack.3d.up",
                        message: t("先运行一次主题建模，WordZ 会把片段聚成主题簇，并提供关键词、代表片段和片段表格供你继续阅读。", "Run topic modeling once and WordZ will build topic clusters with keywords, representative passages, and segment tables for further reading.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
