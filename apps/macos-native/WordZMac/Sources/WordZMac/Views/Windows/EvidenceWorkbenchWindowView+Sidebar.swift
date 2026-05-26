import SwiftUI

struct EvidenceWorkbenchSidebarList: View {
    @ObservedObject var workbench: EvidenceWorkbenchViewModel
    let languageMode: AppLanguageMode
    let onAction: (EvidenceWorkbenchWindowAction) -> Void

    var body: some View {
        List(selection: $workbench.selectedItemID) {
            ForEach(workbench.filteredItems) { item in
                evidenceListRow(item)
                    .tag(item.id)
            }
        }
        .listStyle(.sidebar)
    }

    private func evidenceListRow(_ item: EvidenceItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.keyword.isEmpty ? t("未命名摘录", "Untitled Excerpt") : item.keyword)
                    .lineLimit(1)
                Spacer()
                Text(item.reviewStatus.title(in: languageMode))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(item.corpusName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(item.concordanceText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)

            if let note = workbench.normalizedNote(item.note) {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
