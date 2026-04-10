import SwiftUI

struct StopwordControlsView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @Binding var filter: StopwordFilterState
    @Binding var isEditorPresented: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                stopwordToggle
                modePicker
                editButton
                summaryLabel(lineLimit: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    stopwordToggle
                    modePicker
                }
                HStack(spacing: 12) {
                    editButton
                    summaryLabel(lineLimit: 2)
                }
            }
        }
    }

    private var stopwordToggle: some View {
        Toggle(wordZText("启用停用词", "Enable stopwords", mode: languageMode), isOn: $filter.enabled)
            .toggleStyle(.checkbox)
            .accessibilityLabel(wordZText("启用停用词过滤", "Enable stopword filtering", mode: languageMode))
            .accessibilityHint(wordZText("开启后会按当前词表筛去或仅保留匹配词项；同一份词表也可作为白名单使用。", "When enabled, the current list can exclude matching terms or keep only them; the same list can also work as an allowlist.", mode: languageMode))
    }

    private var modePicker: some View {
        WorkbenchMenuPicker(
            title: wordZText("模式", "Mode", mode: languageMode),
            selection: $filter.mode,
            options: Array(StopwordFilterMode.allCases),
            isDisabled: !filter.enabled
        ) {
            $0.title(in: languageMode)
        }
        .accessibilityLabel(wordZText("停用词模式", "Stopword mode", mode: languageMode))
        .accessibilityHint(wordZText("选择把当前词表当作停用词表，或当作白名单仅保留词表中的词。", "Choose whether the current list works as a stoplist or as an allowlist that keeps only listed words.", mode: languageMode))
    }

    private var editButton: some View {
        Button(wordZText("编辑词表", "Edit list", mode: languageMode)) {
            isEditorPresented = true
        }
        .accessibilityLabel(wordZText("编辑停用词词表", "Edit stopword list", mode: languageMode))
        .accessibilityHint(wordZText("打开词表编辑器以修改停用词或白名单列表。", "Open the editor to modify the stopword or allowlist entries.", mode: languageMode))
    }

    private func summaryLabel(lineLimit: Int) -> some View {
        Text(filter.summaryText(in: languageMode))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }
}
