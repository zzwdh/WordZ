import Foundation

extension WorkspacePresentationService {
    func displayName(
        appInfo: AppInfoSummary?,
        selectedCorpus: LibraryCorpusItem?,
        openedCorpus: OpenedCorpus?
    ) -> String {
        let fallbackTitle = appInfo?.name ?? "WordZ Native Preview"
        return openedCorpus?.displayName ?? selectedCorpus?.name ?? fallbackTitle
    }

    func workspaceSummary(
        selectedCorpus: LibraryCorpusItem?,
        openedCorpus: OpenedCorpus?,
        workspaceSnapshot: WorkspaceSnapshotSummary?
    ) -> String {
        let corpusLabel = openedCorpus?.displayName ?? selectedCorpus?.name ?? "未打开语料"
        let workspaceLabel = workspaceSnapshot?.corpusNames.isEmpty == false
            ? "工作区：\(workspaceSnapshot?.corpusNames.joined(separator: "、") ?? "")"
            : "工作区：空"
        return "\(workspaceLabel) ｜ 当前语料：\(corpusLabel)"
    }
}
