import SwiftUI

struct TokenizeView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: TokenizePageViewModel
    let isBusy: Bool
    let onAction: (TokenizePageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("分词", "Tokenize"),
            scrollMode: .manual
        ) {
            WorkbenchFixedTopScrollContent {
                tokenizeInputSection
            } scrolling: {
                tokenizeResultsSection
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
