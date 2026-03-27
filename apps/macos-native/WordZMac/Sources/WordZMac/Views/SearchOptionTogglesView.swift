import SwiftUI

struct SearchOptionTogglesView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @Binding var options: SearchOptionsState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Toggle(wordZText("整词", "Whole words", mode: languageMode), isOn: $options.words)
                    .toggleStyle(.checkbox)
                    .accessibilityLabel(wordZText("整词匹配", "Whole word matching", mode: languageMode))
                    .accessibilityHint(wordZText("开启后只匹配完整词项。", "When enabled, only full-word matches are returned.", mode: languageMode))
                Toggle(wordZText("区分大小写", "Case sensitive", mode: languageMode), isOn: $options.caseSensitive)
                    .toggleStyle(.checkbox)
                    .accessibilityLabel(wordZText("区分大小写", "Case sensitive", mode: languageMode))
                    .accessibilityHint(wordZText("开启后会区分大小写。", "When enabled, searches respect letter casing.", mode: languageMode))
                Toggle("Regex", isOn: $options.regex)
                    .toggleStyle(.checkbox)
                    .accessibilityLabel(wordZText("正则表达式", "Regular expression", mode: languageMode))
                    .accessibilityHint(wordZText("开启后按正则表达式解释搜索词。", "When enabled, the query is interpreted as a regular expression.", mode: languageMode))
            }

            Text(wordZText("通配支持：`*` 表示任意多个字符，`?` 表示单个字符；开启正则后改按正则解释。", "Wildcard support: `*` matches any number of characters, `?` matches a single character; regex mode keeps true regex behavior.", mode: languageMode))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.vertical, 2)
    }
}

struct StopwordControlsView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @Binding var filter: StopwordFilterState
    @Binding var isEditorPresented: Bool

    var body: some View {
        HStack(spacing: 12) {
            Toggle(wordZText("启用停用词", "Enable stopwords", mode: languageMode), isOn: $filter.enabled)
                .toggleStyle(.checkbox)
                .accessibilityLabel(wordZText("启用停用词过滤", "Enable stopword filtering", mode: languageMode))
                .accessibilityHint(wordZText("开启后会按停用词表保留或筛去词项。", "When enabled, the stopword list will include or exclude matching terms.", mode: languageMode))

            Picker(wordZText("模式", "Mode", mode: languageMode), selection: $filter.mode) {
                ForEach(StopwordFilterMode.allCases) { mode in
                    Text(mode.title(in: languageMode)).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .disabled(!filter.enabled)
            .accessibilityLabel(wordZText("停用词模式", "Stopword mode", mode: languageMode))
            .accessibilityHint(wordZText("选择保留词表中的词，或筛去词表中的词。", "Choose whether to include only listed words or exclude listed words.", mode: languageMode))

            Button(wordZText("编辑词表", "Edit list", mode: languageMode)) {
                isEditorPresented = true
            }
            .accessibilityLabel(wordZText("编辑停用词词表", "Edit stopword list", mode: languageMode))
            .accessibilityHint(wordZText("打开词表编辑器以修改停用词列表。", "Open the editor to modify the stopword list.", mode: languageMode))

            Text(filter.summaryText(in: languageMode))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct StopwordEditorSheet: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @Binding var filter: StopwordFilterState
    @Environment(\.dismiss) private var dismiss
    @State private var draftText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(wordZText("编辑停用词词表", "Edit stopword list", mode: languageMode))
                .font(.title3.weight(.semibold))

            Text(wordZText("支持按换行、空格、逗号或分号分隔。", "Separate entries with new lines, spaces, commas, or semicolons.", mode: languageMode))
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $draftText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 260)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2))
                )
                .accessibilityLabel(wordZText("停用词词表编辑器", "Stopword list editor", mode: languageMode))
                .accessibilityHint(wordZText("可按换行、空格、逗号或分号分隔词项。", "Separate entries with new lines, spaces, commas, or semicolons.", mode: languageMode))

            HStack {
                Button(wordZText("恢复默认", "Restore defaults", mode: languageMode)) {
                    draftText = StopwordFilterState.defaultListText
                }
                Button(wordZText("清空", "Clear", mode: languageMode)) {
                    draftText = ""
                }
                Spacer()
                Button(wordZText("取消", "Cancel", mode: languageMode)) {
                    dismiss()
                }
                Button(wordZText("保存", "Save", mode: languageMode)) {
                    filter.listText = StopwordFilterState.normalizeListText(draftText)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            draftText = filter.listText
        }
    }
}
