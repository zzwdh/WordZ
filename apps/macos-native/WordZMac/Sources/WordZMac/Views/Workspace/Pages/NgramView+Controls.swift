import SwiftUI

extension NgramView {
    var ngramInputSection: some View {
        WorkbenchSearchToolbarSection(
            searchOptions: $viewModel.searchOptions,
            stopwordFilter: $viewModel.stopwordFilter,
            isEditingStopwords: $viewModel.isEditingStopwords
        ) {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
                    WorkbenchAdaptiveControls {
                        HStack(spacing: 12) {
                            searchField
                            ngramSizeField
                        }
                    } compact: {
                        VStack(alignment: .leading, spacing: 12) {
                            searchField
                            HStack(spacing: 12) {
                                ngramSizeField
                                Spacer(minLength: 0)
                            }
                        }
                    }
                } actions: {
                    runButton
                }

                Text(ngramHeaderSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var searchField: some View {
        LexicalAutocompleteTextField(
            title: t("搜索词（留空显示全部）", "Search term (leave blank for all)"),
            text: $viewModel.query,
            searchOptions: viewModel.searchOptions,
            controller: lexicalAutocompleteController
        )
    }

    var ngramSizeField: some View {
        TextField(t("N 值", "N size"), text: $viewModel.ngramSize)
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
    }

    var runButton: some View {
        Button(t("开始统计", "Run N-Gram")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
    }

    var ngramHeaderSummary: String {
        "\(viewModel.ngramSize)-Gram · \(viewModel.query.isEmpty ? t("显示全部", "All terms") : viewModel.query)"
    }
}
