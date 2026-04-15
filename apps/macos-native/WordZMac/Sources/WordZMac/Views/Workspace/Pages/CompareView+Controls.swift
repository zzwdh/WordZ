import SwiftUI

extension CompareView {
    var compareInputSection: some View {
        WorkbenchSearchToolbarSection(
            searchOptions: $viewModel.searchOptions,
            stopwordFilter: $viewModel.stopwordFilter,
            isEditingStopwords: $viewModel.isEditingStopwords
        ) {
            Text(t("选择至少 2 条语料", "Select at least 2 corpora"))
                .font(.headline)
            if viewModel.selectionItems.isEmpty {
                Text(t("当前没有可用于对比的已保存语料。", "No saved corpora are available for comparison."))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.selectionItems) { item in
                            Toggle(isOn: Binding(
                                get: { viewModel.isCorpusSelected(item.id) },
                                set: { _ in onAction(.toggleCorpusSelection(item.id)) }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(item.subtitle.isEmpty ? t("未分类", "Unfiled") : item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .padding(10)
                            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }

            WorkbenchInlineActionStrip {
                WorkbenchAdaptiveControls {
                    HStack(spacing: 12) {
                        searchField
                        referencePicker
                        selectedCountLabel
                    }
                } compact: {
                    VStack(alignment: .leading, spacing: 12) {
                        searchField
                        HStack(spacing: 12) {
                            referencePicker
                            selectedCountLabel
                        }
                    }
                }
            } actions: {
                compareRunButton
            }

            Text(compareControlSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var searchField: some View {
        TextField(t("过滤词（留空显示全部）", "Filter term (leave blank for all)"), text: $viewModel.query)
            .textFieldStyle(.roundedBorder)
    }

    var referencePicker: some View {
        Picker(
            t("参考语料", "Reference Corpus"),
            selection: Binding(
                get: { viewModel.selectedReferenceOptionID },
                set: { onAction(.changeReferenceCorpus($0.isEmpty ? nil : $0)) }
            )
        ) {
            ForEach(viewModel.referenceOptions) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 220, alignment: .leading)
        .disabled(viewModel.referenceOptions.isEmpty)
    }

    var selectedCountLabel: some View {
        Text("\(t("已选", "Selected")) \(viewModel.selectedCorpusCount) \(t("条", "items"))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    var selectedReferenceLabel: String {
        viewModel.referenceOptions.first(where: { $0.id == viewModel.selectedReferenceOptionID })?.title ?? t("自动", "Automatic")
    }

    var compareRunButton: some View {
        Button(t("开始对比", "Run Compare")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy || viewModel.selectedCorpusCount < 2)
    }

    var compareControlSummary: String {
        "\(t("已选", "Selected")) \(viewModel.selectedCorpusCount) · \(selectedReferenceLabel)"
    }
}
