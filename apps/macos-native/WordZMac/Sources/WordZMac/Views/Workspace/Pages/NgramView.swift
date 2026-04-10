import SwiftUI

struct NgramView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: NgramPageViewModel
    let isBusy: Bool
    let onAction: (NgramPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: "N-Gram"
        ) {
            ngramHeaderActions
        } content: {
            ngramInputSection
            ngramResultsSection
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
