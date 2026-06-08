import Foundation

@MainActor
extension MainWorkspaceViewModel {
    @discardableResult
    func performResultArtifactAction(
        _ action: WorkspaceResultArtifactAction,
        preferredWindowRoute: NativeWindowRoute? = nil
    ) async -> Bool {
        switch action {
        case .copy:
            guard let artifact = currentResultArtifact,
                  artifact.supports(.copy)
            else { return false }
            await copyResultArtifact(artifact)
            return true
        case .preview:
            await quickLookCurrentCorpus()
            return true
        case .export:
            guard let artifact = currentResultArtifact,
                  artifact.supports(.export)
            else { return false }
            await exportResultArtifact(artifact, preferredWindowRoute: preferredWindowRoute)
            return true
        case .share:
            await shareCurrentContent()
            return true
        case .openSourceReader:
            guard currentResultArtifact?.supports(.openSourceReader) == true else { return false }
            return await openCurrentSourceReader()
        }
    }

    func copyResultArtifact(_ artifact: WorkspaceResultArtifact) async {
        switch artifact.payload {
        case .table(let snapshot):
            let payload = await Task.detached(priority: .userInitiated) {
                TableExportService().makeTSV(snapshot: snapshot)
            }.value
            guard !payload.isEmpty else {
                settings.setSupportStatus(t("当前没有可复制的结果表。", "There is no result table to copy."))
                return
            }
            hostActionService.copyTextToClipboard(payload)
            settings.setSupportStatus(t("已复制当前结果表，可直接粘贴到 Excel。", "Copied the current result table for pasting into Excel."))
            clearActiveIssue()
        case .textDocument(let document):
            guard !document.text.isEmpty else {
                settings.setSupportStatus(t("当前没有可复制的结果文本。", "There is no result text to copy."))
                return
            }
            hostActionService.copyTextToClipboard(document.text)
            settings.setSupportStatus(t("已复制当前结果文本。", "Copied the current result text."))
            clearActiveIssue()
        }
    }

}
