import SwiftUI

struct EvidenceWorkbenchDetailActionRow: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel

    let item: EvidenceItem
    let onAction: (EvidenceWorkbenchWindowAction) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(t("复制引文", "Copy Citation")) {
                onAction(.copyCitation(itemID: item.id))
            }

            Button(t("保存保留摘录…", "Save Kept Excerpts…")) {
                onAction(.exportMarkdown)
            }
            .disabled(!workbench.items.contains(where: { $0.reviewStatus == .keep }))

            Button(t("保存整理", "Save Notes")) {
                onAction(.saveDetails)
            }
            .disabled(!workbench.hasUnsavedDetailChanges)

            Button(role: .destructive) {
                onAction(.deleteItem(itemID: item.id))
            } label: {
                Text(t("删除条目", "Delete Item"))
            }

            Spacer()
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct EvidenceWorkbenchDetailEmptyState: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("还没有摘录", "No Excerpts Yet"))
                .font(.title3.weight(.semibold))
            Text(
                t(
                    "从分析结果里复制表格、截图或把少量关键句暂存到这里；真正的论证结构仍然回到 Word 里完成。",
                    "Copy tables, screenshots, or save a few key lines here; keep the actual argument structure in Word."
                )
            )
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
