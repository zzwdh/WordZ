import Foundation

@MainActor
extension WorkspaceEvidenceWorkflowService {
    func copyEvidenceCitation(
        itemID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        guard let item = features.evidenceWorkbench.items.first(where: { $0.id == itemID }) else {
            features.sidebar.setError(wordZText("未找到要复制的摘录。", "The excerpt could not be found.", mode: .system))
            return
        }
        hostActionService.copyTextToClipboard(item.styledCitationText)
        features.library.setStatus(wordZText("已复制摘录引文。", "Copied the excerpt citation.", mode: .system))
        features.sidebar.clearError()
    }

    func exportEvidencePacketMarkdown(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            let document = try EvidenceMarkdownPacketSupport.document(
                items: features.evidenceWorkbench.filteredItems,
                filterSummary: features.evidenceWorkbench.exportScopeSummary(in: .system)
            )
            await exportTextDocument(
                document,
                title: wordZText("保存摘录", "Save Excerpts", mode: .system),
                successStatus: wordZText("已保存摘录到", "Saved excerpts to", mode: .system),
                features: features,
                preferredRoute: preferredRoute
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportEvidenceJSON(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        let exportItems = features.evidenceWorkbench.filteredItems
        guard !exportItems.isEmpty else {
            features.sidebar.setError(wordZText("当前没有可导出的摘录。", "There are no excerpts to export.", mode: .system))
            return
        }

        guard let path = await dialogService.chooseSavePath(
            title: wordZText("导出摘录 JSON", "Export Excerpts JSON", mode: .system),
            suggestedName: "wordz-excerpts.json",
            allowedExtension: "json",
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let data = try EvidenceTransferSupport.exportData(items: exportItems)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            features.library.setStatus(wordZText("已导出摘录 JSON 到", "Exported excerpts JSON to", mode: .system) + " " + path)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
