import SwiftUI

struct SourceReaderInlineEvidenceDraftView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var sourceReader: SourceReaderViewModel
    let onCopyCitation: () -> Void
    let onAddClip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(t("摘录", "Excerpt"), systemImage: "text.badge.checkmark")
                    .font(.headline)

                Spacer()

                Button {
                    onCopyCitation()
                } label: {
                    Label(t("复制引文", "Copy Citation"), systemImage: "doc.on.doc")
                }
                .disabled(sourceReader.currentPreparedCitationText == nil)

                Button {
                    onAddClip()
                } label: {
                    Label(t("暂存摘录", "Save Excerpt"), systemImage: "tray.and.arrow.down")
                }
                .disabled(!sourceReader.canAddEvidence)
            }

            if let preview = sourceReader.currentPreparedCitationText {
                citationPreview(preview)
            }

            citationControls

            VStack(alignment: .leading, spacing: 6) {
                Text(t("备注", "Note"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: $sourceReader.captureNote)
                    .font(.body)
                    .frame(minHeight: 76)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(WordZTheme.divider.opacity(0.45))
                    )
            }
        }
    }

    private var citationControls: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Picker(
                    t("引文文本", "Citation Text"),
                    selection: $sourceReader.captureCitationFormat
                ) {
                    ForEach(EvidenceCitationFormat.allCases) { format in
                        Text(format.title(in: languageMode))
                            .tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Text(sourceReader.captureCitationFormat.summary(in: languageMode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Picker(
                    t("引用样式", "Reference Style"),
                    selection: $sourceReader.captureCitationStyle
                ) {
                    ForEach(EvidenceCitationStyle.allCases) { style in
                        Text(style.title(in: languageMode))
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(sourceReader.captureCitationStyle.summary(in: languageMode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func citationPreview(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("复制预览", "Copy Preview"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(WordZTheme.primarySurfaceSoft)
        )
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
