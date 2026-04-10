import SwiftUI

struct WordView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: WordPageViewModel
    let isBusy: Bool
    let onAction: (WordPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("词表", "Word")
        ) {
            wordHeaderActions
        } content: {
            wordInputSection
            wordResultsSection
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
