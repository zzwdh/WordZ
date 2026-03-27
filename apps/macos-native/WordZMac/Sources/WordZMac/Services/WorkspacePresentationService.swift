import Foundation

struct WorkspacePresentationService {
    func buildPresentation(
        appInfo: AppInfoSummary?,
        selectedCorpus: LibraryCorpusItem?,
        openedCorpus: OpenedCorpus?,
        workspaceSnapshot: WorkspaceSnapshotSummary?
    ) -> WorkspacePresentationSnapshot {
        let fallbackTitle = appInfo?.name ?? "WordZ Native Preview"
        let displayName = openedCorpus?.displayName ?? selectedCorpus?.name ?? fallbackTitle
        let representedPath = openedCorpus?.filePath ?? ""
        let corpusLabel = openedCorpus?.displayName ?? selectedCorpus?.name ?? "未打开语料"
        let workspaceLabel = workspaceSnapshot?.corpusNames.isEmpty == false
            ? "工作区：\(workspaceSnapshot?.corpusNames.joined(separator: "、") ?? "")"
            : "工作区：空"

        return WorkspacePresentationSnapshot(
            displayName: displayName,
            representedPath: representedPath,
            workspaceSummary: "\(workspaceLabel) ｜ 当前语料：\(corpusLabel)"
        )
    }
}
