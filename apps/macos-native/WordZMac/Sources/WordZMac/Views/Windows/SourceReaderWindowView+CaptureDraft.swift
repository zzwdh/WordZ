import SwiftUI

struct SourceReaderCaptureDraftCard: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var sourceReader: SourceReaderViewModel

    var body: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("加入 Workbench 时附带", "Attach When Adding to Workbench"))
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
                            "这些字段会随当前命中一并写入 Evidence Workbench，适合先在阅读时完成 dossier 初步整理。",
                            "These fields are stored together with the current hit when you add it to the workbench, so you can organize the dossier while reading."
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
