import SwiftUI

struct ClusterView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @EnvironmentObject var lexicalAutocompleteController: LexicalAutocompleteController
    @ObservedObject var viewModel: ClusterPageViewModel
    let isBusy: Bool
    let onAction: (ClusterPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: t("词串簇", "Cluster"),
            scrollMode: .manual
        ) {
            WorkbenchFixedTopScrollContent {
                clusterInputSection
            } scrolling: {
                clusterResultsSection
            }
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    private var clusterInputSection: some View {
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
                            nPicker
                            minFrequencyField
                            modePicker
                            punctuationPicker
                        }
                    } compact: {
                        VStack(alignment: .leading, spacing: 12) {
                            searchField
                            HStack(spacing: 12) {
                                nPicker
                                minFrequencyField
                            }
                            HStack(spacing: 12) {
                                modePicker
                                punctuationPicker
                            }
                        }
                    }
                } actions: {
                    HStack(spacing: 8) {
                        Button(t("运行", "Run Cluster")) { onAction(.run) }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)

                        Button {
                            onAction(.openKWIC)
                        } label: {
                            Label("KWIC", systemImage: "quote.opening")
                        }
                        .disabled(viewModel.selectedSceneRow == nil || isBusy)
                    }
                }

                Toggle(t("区分大小写", "Case Sensitive"), isOn: Binding(
                    get: { viewModel.caseSensitive },
                    set: { onAction(.changeCaseSensitive($0)) }
                ))

                if viewModel.mode == .targetReference {
                    referencePicker
                }
            }
        }
    }

    @ViewBuilder
    private var clusterResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchResultsToolbarSection {
                Text(scene.mode.title(in: languageMode))
                    .font(.headline)
                Text("N = \(scene.selectedN) · \(t("最小频次", "Min Freq")) \(scene.minimumFrequency)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(scene.annotationSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if !scene.searchError.isEmpty {
                    Text(scene.searchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } trailing: {
                Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)（\(t("总计", "Total")) \(scene.totalRows)）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } leadingControls: {
                HStack(spacing: 12) {
                    WorkbenchMenuPicker(
                        title: t("排序", "Sort"),
                        selection: Binding(
                            get: { scene.sorting.selectedSort },
                            set: { onAction(.changeSort($0)) }
                        ),
                        options: Array(ClusterSortMode.allCases)
                    ) {
                        $0.title(in: languageMode)
                    }

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
            } trailingControls: {
                WorkbenchResultTrailingControls(
                    columnMenuTitle: t("列", "Columns"),
                    keys: ClusterColumnKey.allCases,
                    label: { scene.columnTitle(for: $0, mode: languageMode) },
                    isVisible: { scene.column(for: $0)?.isVisible ?? false },
                    onToggle: { onAction(.toggleColumn($0)) },
                    canGoBackward: scene.pagination.canGoBackward,
                    canGoForward: scene.pagination.canGoForward,
                    rangeLabel: scene.pagination.rangeLabel,
                    onPrevious: { onAction(.previousPage) },
                    onNext: { onAction(.nextPage) }
                )
            }

            WorkbenchTableCard {
                NativeTableView(
                    descriptor: scene.table,
                    rows: scene.tableRows,
                    selectedRowID: viewModel.selectedRowID,
                    onSelectionChange: { onAction(.selectRow($0)) },
                    onDoubleClick: { onAction(.activateRow($0)) },
                    onSortByColumn: { columnID in
                        guard let column = ClusterColumnKey(rawValue: columnID) else { return }
                        onAction(.sortByColumn(column))
                    },
                    onToggleColumnFromHeader: { columnID in
                        guard let column = ClusterColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    allowsMultipleSelection: false,
                    emptyMessage: t("当前 Cluster 结果没有可显示的词串。", "No cluster rows to display."),
                    accessibilityLabel: t("Cluster 结果表格", "Cluster results table"),
                    activationHint: t("使用方向键浏览结果，按 Return 打开当前词串的 KWIC。", "Use arrow keys to browse results, then press Return to open KWIC for the selected phrase.")
                )
            }

            if let selectedRow = viewModel.selectedSceneRow {
                WorkbenchSectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedRow.phrase)
                            .font(.headline)
                        Text("N \(selectedRow.n) · Freq \(selectedRow.frequency) · Range \(selectedRow.range)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            onAction(.openKWIC)
                        } label: {
                            Label(t("查看 KWIC", "Open KWIC"), systemImage: "quote.opening")
                        }
                    }
                }
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成 Cluster 结果", "No Cluster results yet"),
                systemImage: "square.stack.3d.up",
                message: t("运行后这里会显示连续高频词串，并支持进一步下钻到 KWIC。", "Run the analysis to see contiguous lexical bundles and drill down into KWIC.")
            )
        }
    }

    private var searchField: some View {
        LexicalAutocompleteTextField(
            title: t("搜索词串（留空显示全部）", "Search phrase (leave blank for all)"),
            text: $viewModel.query,
            searchOptions: viewModel.searchOptions,
            controller: lexicalAutocompleteController
        )
    }

    private var nPicker: some View {
        Picker("N", selection: Binding(
            get: { viewModel.selectedNValue },
            set: { onAction(.changeSelectedN($0)) }
        )) {
            ForEach([2, 3, 4, 5], id: \.self) { value in
                Text("\(value)").tag(value)
            }
        }
        .pickerStyle(.menu)
    }

    private var minFrequencyField: some View {
        TextField(t("最小频次", "Min Freq"), text: $viewModel.minimumFrequency)
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
    }

    private var modePicker: some View {
        WorkbenchMenuPicker(
            title: t("模式", "Mode"),
            selection: $viewModel.mode,
            options: ClusterMode.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    private var punctuationPicker: some View {
        WorkbenchMenuPicker(
            title: t("标点", "Punctuation"),
            selection: $viewModel.punctuationMode,
            options: ClusterPunctuationMode.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    private var referencePicker: some View {
        Picker(
            t("参考语料", "Reference Corpus"),
            selection: Binding(
                get: { viewModel.referenceCorpusID },
                set: { onAction(.changeReferenceCorpus($0.isEmpty ? nil : $0)) }
            )
        ) {
            Text(t("未选择", "None")).tag("")
            ForEach(viewModel.referenceCorpusOptions) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
