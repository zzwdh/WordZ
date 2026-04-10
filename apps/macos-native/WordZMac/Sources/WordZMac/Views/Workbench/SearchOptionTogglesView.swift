import SwiftUI

struct SearchOptionTogglesView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @Binding var options: SearchOptionsState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    optionToggles
                }
                VStack(alignment: .leading, spacing: 8) {
                    optionToggles
                }
            }

            Text(wordZText("通配支持：`*` 表示任意多个字符，`?` 表示单个字符；开启正则后改按正则解释。", "Wildcard support: `*` matches any number of characters, `?` matches a single character; regex mode keeps true regex behavior.", mode: languageMode))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var optionToggles: some View {
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
}
