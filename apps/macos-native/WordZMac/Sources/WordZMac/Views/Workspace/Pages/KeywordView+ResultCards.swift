import SwiftUI

extension KeywordView {
    func keywordResultsSummaryCard(_ scene: KeywordSceneModel) -> some View {
        WorkbenchHeaderCard(
            title: t("Focus / Reference 摘要", "Focus / Reference Summary"),
            subtitle: [scene.annotationSummary, scene.configurationSummary].joined(separator: "\n")
        ) {
            HStack(spacing: 12) {
                WorkbenchMetricCard(title: t("Focus", "Focus"), value: scene.focusSummary)
                WorkbenchMetricCard(title: t("Reference", "Reference"), value: scene.referenceSummary)
            }
            .frame(maxWidth: 720)
        }
    }

    func keywordResultsMethodCard(_ scene: KeywordSceneModel) -> some View {
        WorkbenchMethodNoteCard(
            title: t("结果说明", "How to Read These Results"),
            summary: scene.methodSummary,
            notes: scene.methodNotes
        )
    }

    var keywordEmptyState: some View {
        WorkbenchEmptyStateCard(
            title: t("尚未生成 Keyword Suite 结果", "No Keyword Suite results yet"),
            systemImage: "text.magnifyingglass",
            message: t(
                "先选择显式 Focus / Reference，再运行 Keyword Suite。Words、Terms 和 N-grams 会共享同一套配置。",
                "Choose explicit focus/reference scopes and run Keyword Suite. Words, Terms, and N-grams share the same configuration."
            ),
            suggestions: [
                t("Words 适合先看单词级差异，再转到 Terms / N-grams。", "Start with Words, then move to Terms or N-grams for multiword items."),
                t("如果想复用结果，先给当前页签输入一个词表名称并保存。", "If you want to reuse results, save the current tab as a named list.")
            ]
        ) {
            runButton
        }
    }

    func keywordResultHeaderTitle(_ scene: KeywordSceneModel) -> String {
        switch scene.activeTab {
        case .words:
            return t("Words 关键词结果", "Words keyword results")
        case .terms:
            return t("Terms 关键词结果", "Terms keyword results")
        case .ngrams:
            return t("N-grams 关键词结果", "N-grams keyword results")
        case .lists:
            return scene.listMode.title(in: languageMode)
        }
    }
}
