import SwiftUI

struct LocatorView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var viewModel: LocatorPageViewModel
    @ObservedObject var evidenceWorkbench: EvidenceWorkbenchViewModel
    let isBusy: Bool
    let onAction: (LocatorPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("定位器", "Locator"),
            scrollMode: .manual
        ) {
            WorkbenchFixedTopScrollContent {
                locatorInputSection
            } scrolling: {
                locatorResultsSection
            }
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    func openEvidenceWorkbenchWindow() {
        openWindow(id: NativeWindowRoute.evidenceWorkbench.id)
    }
}
