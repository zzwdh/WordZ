import SwiftUI

struct StatsView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @Environment(\.openWindow) var openWindow
    @ObservedObject var viewModel: StatsPageViewModel
    @ObservedObject var sidebar: LibrarySidebarViewModel
    let isBusy: Bool
    let onAction: (StatsPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("统计", "Stats"),
            scrollMode: .manual
        ) {
            WorkbenchFixedTopScrollContent {
                metadataFiltersSection
            } scrolling: {
                if let scene = viewModel.scene {
                    summarySection(scene)
                    resultsSection(scene)
                    tableSection(scene)
                } else {
                    emptyState
                }
            }
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
