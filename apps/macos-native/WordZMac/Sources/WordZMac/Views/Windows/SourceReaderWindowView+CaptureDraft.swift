import SwiftUI

struct SourceReaderCaptureDraftCard: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var sourceReader: SourceReaderViewModel

    var body: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("加入摘录时附带", "Attach When Adding to Clips"))
                    .font(.headline)

                TextField(
                    t("章节标题", "Section Title"),
                    text: $sourceReader.captureSectionTitle
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    t("论点 / Claim", "Claim"),
                    text: $sourceReader.captureClaim
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    t("标签（逗号分隔）", "Tags (comma separated)"),
                    text: $sourceReader.captureTagsText
                )
                .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 6) {
                    Text(t("备注", "Note"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $sourceReader.captureNote)
                        .font(.body)
                        .frame(minHeight: 90)
                }

                if let summary = sourceReader.captureDraftSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(
                        t(
                            "这些字段会随当前命中一并写入摘录，适合阅读时先补充章节、论点和备注。",
                            "These fields are stored together with the current hit when you add it to clips, so you can capture section, claim, and note details while reading."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
