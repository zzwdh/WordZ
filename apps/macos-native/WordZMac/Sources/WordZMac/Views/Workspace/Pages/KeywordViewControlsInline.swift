import SwiftUI

extension KeywordView {
    var keywordInputSection: some View {
        WorkbenchToolbarSection {
            VStack(alignment: .leading, spacing: 12) {
                Picker("", selection: Binding(
                    get: { viewModel.activeTab },
                    set: { onAction(.changeTab($0)) }
                )) {
                    ForEach(KeywordSuiteTab.allCases) { tab in
                        Text(tab.title(in: languageMode)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                Text(keywordHeaderSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.activeTab == .lists {
                    keywordListsControls
                } else {
                    keywordSuiteControls
                }
            }
        }
    }

    var runButton: some View {
        Button(t("运行 Keyword Suite", "Run Keyword Suite")) {
            onAction(.run)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isBusy || !viewModel.canRun)
    }

    var keywordHeaderSummary: String {
        [
            "\(viewModel.focusSelectionSummary) → \(viewModel.referenceSelectionSummary)",
            viewModel.annotationSummary(in: languageMode)
        ].joined(separator: "\n")
    }
}
