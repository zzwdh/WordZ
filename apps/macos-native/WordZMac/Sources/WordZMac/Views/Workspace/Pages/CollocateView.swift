import SwiftUI

struct CollocateView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: CollocatePageViewModel
    let isBusy: Bool
    let onAction: (CollocatePageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("搭配词", "Collocate")
        ) {
            collocateHeader
        } content: {
            collocateInputSection
            collocateResultsSection
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
