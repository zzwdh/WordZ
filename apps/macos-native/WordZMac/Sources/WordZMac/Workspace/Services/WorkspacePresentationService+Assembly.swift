import Foundation

extension WorkspacePresentationService {
    func buildPresentation(
        appInfo: AppInfoSummary?,
        selectedCorpus: LibraryCorpusItem?,
        openedCorpus: OpenedCorpus?,
        workspaceSnapshot: WorkspaceSnapshotSummary?
    ) -> WorkspacePresentationSnapshot {
        WorkspacePresentationSnapshot(
            displayName: displayName(
                appInfo: appInfo,
                selectedCorpus: selectedCorpus,
                openedCorpus: openedCorpus
            ),
            representedPath: openedCorpus?.filePath ?? "",
            workspaceSummary: workspaceSummary(
                selectedCorpus: selectedCorpus,
                openedCorpus: openedCorpus,
                workspaceSnapshot: workspaceSnapshot
            )
        )
    }
}
