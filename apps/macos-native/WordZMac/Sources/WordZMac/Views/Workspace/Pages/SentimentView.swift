import Charts
import SwiftUI

struct SentimentView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: SentimentPageViewModel
    let isBusy: Bool
    let onAction: (SentimentPageAction) -> Void

    let summaryColumns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        UtilityPageScaffold(
            title: t("情感", "Sentiment"),
            scrollMode: .manual
        ) {
            WorkbenchFixedTopScrollContent {
                sentimentControlsSection
            } scrolling: {
                sentimentResultsSection
            }
        }
    }
}
