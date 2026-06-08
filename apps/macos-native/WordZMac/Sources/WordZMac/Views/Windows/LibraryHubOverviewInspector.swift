import SwiftUI

struct LibraryHubOverviewInspector: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    let scene: LibraryManagementSceneModel
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdaptiveInspectorSurface {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("语料库概览", "Library Overview"))
                            .font(.headline)
                        Text(scene.currentScopeSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            NativeWindowSection(
                title: t("当前范围", "Current Scope"),
                subtitle: scene.statusMessage
            ) {
                inspectorRow(title: t("语料", "Corpora"), value: "\(scene.integritySummary.visibleCorpusCount)")
                inspectorRow(title: t("文件夹", "Folders"), value: "\(scene.folders.count)")
                inspectorRow(title: t("语料集", "Corpus Sets"), value: "\(scene.corpusSets.count + scene.recentCorpusSets.count)")
                inspectorRow(title: t("回收站", "Recycle Bin"), value: scene.recycleSummary)
            }

            NativeWindowSection(
                title: t("整理状态", "Curation Status"),
                subtitle: scene.readinessSummary.actionSummaryText
            ) {
                inspectorRow(title: t("平均可用度", "Average Readiness"), value: scene.readinessSummary.averageScoreText)
                inspectorRow(title: t("元数据完整率", "Metadata Complete"), value: scene.metadataStudio.completionText)
                inspectorRow(title: t("待清洗", "Pending Cleaning"), value: "\(scene.autoCleaningSummary.pendingCount)")
            }

            LibraryInspectorActionsView(
                actions: overviewActions,
                onAction: onAction
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var overviewActions: [LibraryManagementInspectorActionItem] {
        var actions: [LibraryManagementInspectorActionItem] = [
            .init(id: "import", title: t("添加文件", "Add Files"), role: .primary, action: .importPaths),
            .init(id: "builder", title: t("导入视图", "Import View"), role: .normal, action: .showCorpusBuilder),
            .init(id: "backup", title: t("备份语料库", "Back Up Library"), role: .normal, action: .backupLibrary),
            .init(id: "repair", title: t("修复语料库", "Repair Library"), role: .normal, action: .repairLibrary)
        ]
        if scene.integritySummary.visibleCorpusCount > 0 {
            actions.insert(
                .init(id: "save-set", title: t("保存范围", "Save Scope"), role: .normal, action: .saveCurrentCorpusSet),
                at: 2
            )
        }
        return actions
    }

    private func inspectorRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 94, alignment: .leading)
            Text(value)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
