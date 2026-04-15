import SwiftUI

extension KeywordView {
    func corpusPicker(title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text(t("未选择", "None")).tag("")
            ForEach(viewModel.corpusOptions) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
    }

    func corpusSetPicker(title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text(t("未选择", "None")).tag("")
            ForEach(viewModel.corpusSetOptions) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
    }

    func savedListPicker(title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text(t("未选择", "None")).tag("")
            ForEach(viewModel.savedLists) { list in
                Text("\(list.name) · \(list.group.title(in: languageMode))").tag(list.id)
            }
        }
        .pickerStyle(.menu)
    }

    func keywordThresholdField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 92)
        }
    }

    func keywordCorpusSelectionGrid(
        options: [KeywordCorpusOptionSceneItem],
        selectedIDs: Set<String>,
        toggle: @escaping (String) -> Void
    ) -> some View {
        FlowLayout(data: options.map(corpusChipItem)) { item in
            Button {
                toggle(item.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selectedIDs.contains(item.id) ? WordZTheme.primarySurface : WordZTheme.primarySurfaceSoft)
                )
            }
            .buttonStyle(.plain)
        }
    }

    func corpusChipItem(_ option: KeywordCorpusOptionSceneItem) -> KeywordChipItem {
        KeywordChipItem(id: option.id, title: option.title, subtitle: option.subtitle)
    }

    func savedListChipItem(_ list: KeywordSavedList) -> KeywordChipItem {
        KeywordChipItem(
            id: list.id,
            title: "\(list.name) · \(list.group.title(in: languageMode))",
            subtitle: "\(list.focusLabel) → \(list.referenceLabel)"
        )
    }
}

struct KeywordChipItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
}
