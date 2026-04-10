import SwiftUI

struct StatsView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: StatsPageViewModel
    @ObservedObject var sidebar: LibrarySidebarViewModel
    let isBusy: Bool
    let onAction: (StatsPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("统计", "Stats")
        ) {
            WorkbenchPageHeaderActions(
                summary: "\(t("语料", "Corpora")) \(sidebar.filteredCorpusCount) · \(sidebar.metadataFilterState.summaryText(in: languageMode) ?? t("全部语料", "All corpora"))",
                layout: .trailingStack
            ) {
                Button(t("开始统计", "Run Stats")) { onAction(.run) }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
            }
        } content: {
            metadataFiltersSection
            if let scene = viewModel.scene {
                summarySection(scene)
                resultsSection(scene)
                tableSection(scene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                emptyState
            }
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
