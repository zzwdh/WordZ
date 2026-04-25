import SwiftUI

extension WordView {
    var wordInputSection: some View {
        WorkbenchSearchToolbarSection(
            searchOptions: $viewModel.searchOptions,
            stopwordFilter: $viewModel.stopwordFilter,
            isEditingStopwords: $viewModel.isEditingStopwords
        ) {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
                    searchField
                } actions: {
                    wordRunButton
                }

                Text(wordControlSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func sortPicker(for scene: WordSceneModel) -> some View {
        WorkbenchMenuPicker(
            title: t("排序", "Sort"),
            selection: Binding(
                get: { scene.sorting.selectedSort },
                set: { onAction(.changeSort($0)) }
            ),
            options: Array(WordSortMode.allCases)
        ) {
            $0.title(in: languageMode)
        }
    }

    func definitionControls(for scene: WordSceneModel) -> some View {
        HStack(spacing: 12) {
            WorkbenchMenuPicker(
                title: t("标准频次", "Norm Frequency"),
                selection: Binding(
                    get: { scene.definition.normalizationUnit },
                    set: { onAction(.changeNormalizationUnit($0)) }
                ),
                options: Array(FrequencyNormalizationUnit.allCases)
            ) {
                $0.title(in: languageMode)
            }

            WorkbenchMenuPicker(
                title: t("Range 口径", "Range Definition"),
                selection: Binding(
                    get: { scene.definition.rangeMode },
                    set: { onAction(.changeRangeMode($0)) }
                ),
                options: Array(FrequencyRangeMode.allCases)
            ) {
                $0.title(in: languageMode)
            }
        }
    }

    func pageSizePicker(for scene: WordSceneModel) -> some View {
        WorkbenchGuardedPageSizePicker(
            title: t("页大小", "Page Size"),
            selection: Binding(
                get: { scene.sorting.selectedPageSize },
                set: { onAction(.changePageSize($0)) }
            ),
            totalRows: scene.filteredRows
        ) {
            $0.title(in: languageMode)
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

    var wordRunButton: some View {
        Button(t("开始统计", "Run Word")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
    }

    var wordControlSummary: String {
        "\(viewModel.query.isEmpty ? t("全部词项", "All terms") : viewModel.query) · \(viewModel.stopwordFilter.summaryText(in: languageMode))"
    }
}
