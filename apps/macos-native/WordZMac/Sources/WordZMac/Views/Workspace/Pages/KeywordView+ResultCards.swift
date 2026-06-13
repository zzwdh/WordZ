import SwiftUI

extension KeywordView {
    func keywordResultsSummaryCard(_ scene: KeywordSceneModel) -> some View {
        WorkbenchHeaderCard(
            title: t("目标 / 参照摘要", "Focus / Reference Summary"),
            subtitle: [scene.annotationSummary, scene.configurationSummary].joined(separator: "\n")
        ) {
            HStack(spacing: 12) {
                WorkbenchMetricCard(title: t("目标语料", "Focus"), value: scene.focusSummary)
                WorkbenchMetricCard(title: t("参照语料", "Reference"), value: scene.referenceSummary)
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
            title: t("尚未生成关键词结果", "No keyword results yet"),
            systemImage: "text.magnifyingglass",
            message: t(
                "先选择目标语料和参照语料，再运行关键词计算。词、术语和 N-grams 会共享同一套配置。",
                "Choose focus and reference scopes, then run keyword analysis. Words, Terms, and N-grams share the same configuration."
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
            return t("词关键词结果", "Words keyword results")
        case .terms:
            return t("术语关键词结果", "Terms keyword results")
        case .ngrams:
            return t("N-grams 关键词结果", "N-grams keyword results")
        case .lists:
            return scene.listMode.title(in: languageMode)
        }
    }
}
