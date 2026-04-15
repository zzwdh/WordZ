import SwiftUI

struct CompareView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: ComparePageViewModel
    let isBusy: Bool
    let onAction: (ComparePageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("对比", "Compare"),
            scrollMode: .manual
        ) {
            WorkbenchFixedTopScrollContent {
                compareInputSection
            } scrolling: {
                compareResultsSection
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
