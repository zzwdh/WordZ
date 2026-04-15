import SwiftUI

extension KeywordView {
    var keywordListsControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    keywordSavedListModePicker
                    keywordSavedListTransferButtons
                }

                VStack(alignment: .leading, spacing: 10) {
                    keywordSavedListModePicker
                    keywordSavedListTransferButtons
                }
            }

            if viewModel.savedListViewMode == .pairwiseDiff {
                HStack(spacing: 12) {
                    savedListPicker(
                        title: t("左侧词表", "Left List"),
                        selection: Binding(
                            get: { viewModel.selectedSavedListID ?? "" },
                            set: { viewModel.selectedSavedListID = $0.isEmpty ? nil : $0 }
                        )
                    )
                    savedListPicker(
                        title: t("右侧词表", "Right List"),
                        selection: Binding(
                            get: { viewModel.comparisonSavedListID ?? "" },
                            set: { viewModel.comparisonSavedListID = $0.isEmpty ? nil : $0 }
                        )
                    )
                }
            }

            if !viewModel.savedLists.isEmpty {
                keywordSavedListChips
            }
        }
    }

    var keywordSavedListModePicker: some View {
        Picker("", selection: $viewModel.savedListViewMode) {
            ForEach(KeywordSavedListViewMode.allCases) { mode in
                Text(mode.title(in: languageMode)).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    var keywordSavedListTransferButtons: some View {
        HStack(spacing: 8) {
            Button(t("导入 JSON", "Import JSON")) {
                onAction(.importSavedListsJSON)
            }
            .buttonStyle(.bordered)

            Button(t("导出所选 JSON", "Export Selected JSON")) {
                onAction(.exportSelectedSavedListJSON)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedSavedList == nil)

            Button(t("导出全部 JSON", "Export All JSON")) {
                onAction(.exportAllSavedListsJSON)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.savedLists.isEmpty)

            Button(t("刷新词表", "Refresh Lists")) {
                onAction(.refreshSavedLists)
            }
            .buttonStyle(.bordered)
        }
    }

    var keywordSavedListChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("已保存词表", "Saved Lists"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout(data: viewModel.savedLists.map(savedListChipItem)) { item in
                HStack(spacing: 8) {
                    Button(item.title) {
                        viewModel.selectedSavedListID = item.id
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        onAction(.deleteSavedList(item.id))
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(viewModel.selectedSavedListID == item.id ? WordZTheme.primarySurface : WordZTheme.primarySurfaceSoft)
                )
            }
        }
    }
}
