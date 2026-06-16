import SwiftUI
import WordZShared

struct KWICView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @EnvironmentObject var lexicalAutocompleteController: LexicalAutocompleteController
    @ObservedObject var viewModel: KWICPageViewModel
    @State var isSelectedRowContextExpanded = false
    let isBusy: Bool
    let onAction: (KWICPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: "KWIC",
            scrollMode: .manual
        ) {
            WorkbenchFixedTopScrollContent {
                kwicInputSection
            } scrolling: {
                kwicResultsSection
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
