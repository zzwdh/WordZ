import SwiftUI

struct KWICView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: KWICPageViewModel
    let isBusy: Bool
    let onAction: (KWICPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: "KWIC"
        ) {
            kwicHeaderActions
        } content: {
            kwicInputSection
            kwicResultsSection
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
