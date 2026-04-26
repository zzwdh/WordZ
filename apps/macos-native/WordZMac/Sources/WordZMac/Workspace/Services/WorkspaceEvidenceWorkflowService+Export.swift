import Foundation

@MainActor
extension WorkspaceEvidenceWorkflowService {
    func copyEvidenceCitation(
        itemID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        guard let item = features.evidenceWorkbench.items.first(where: { $0.id == itemID }) else {
            features.sidebar.setError(wordZText("未找到要复制的证据条目。", "The evidence item could not be found.", mode: .system))
            return
        }
        hostActionService.copyTextToClipboard(item.styledCitationText)
        features.library.setStatus(wordZText("已复制证据引文。", "Copied the evidence citation.", mode: .system))
        features.sidebar.clearError()
    }

    func exportEvidencePacketMarkdown(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            let document = try EvidenceMarkdownPacketSupport.document(
                items: features.evidenceWorkbench.filteredItems,
                grouping: features.evidenceWorkbench.groupingMode,
                filterSummary: features.evidenceWorkbench.exportScopeSummary(in: .system)
            )
            await exportTextDocument(
                document,
                title: wordZText("导出研究 dossier", "Export Research Dossier", mode: .system),
                successStatus: wordZText("已导出研究 dossier 到", "Exported the research dossier to", mode: .system),
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
            features.sidebar.setError(wordZText("当前没有可导出的证据条目。", "There are no evidence items to export.", mode: .system))
            return
        }

        guard let path = await dialogService.chooseSavePath(
            title: wordZText("导出 dossier JSON", "Export Dossier JSON", mode: .system),
            suggestedName: "research-dossier.json",
            allowedExtension: "json",
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let data = try EvidenceTransferSupport.exportData(items: exportItems)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            features.library.setStatus(wordZText("已导出证据 JSON 到", "Exported evidence JSON to", mode: .system) + " " + path)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
