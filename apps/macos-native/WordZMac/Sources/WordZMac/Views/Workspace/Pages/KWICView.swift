import SwiftUI

struct KWICView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var viewModel: KWICPageViewModel
    @ObservedObject var evidenceWorkbench: EvidenceWorkbenchViewModel
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

    func openEvidenceWorkbenchWindow() {
        openWindow(id: NativeWindowRoute.evidenceWorkbench.id)
    }
}
