import SwiftUI

struct StopwordEditorSheet: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @Binding var filter: StopwordFilterState
    @Environment(\.dismiss) private var dismiss
    @State private var draftText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(wordZText("编辑词表（停用词 / 白名单）", "Edit list (stoplist / allowlist)", mode: languageMode))
                .font(.title3.weight(.semibold))

            Text(wordZText("支持按换行、空格、逗号或分号分隔；在“仅保留词表内词项”模式下，这份词表会作为白名单使用。", "Separate entries with new lines, spaces, commas, or semicolons. In “Keep only listed words” mode, this list works as an allowlist.", mode: languageMode))
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
