import SwiftUI

struct KeywordView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: KeywordPageViewModel
    let isBusy: Bool
    let onAction: (KeywordPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("关键词", "Keyword")
        ) {
            keywordHeaderActions
        } content: {
            keywordInputSection
            keywordResultsSection
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
