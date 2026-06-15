import Foundation
import WordZShared

@MainActor
extension WorkspaceEvidenceWorkflowService {
    func updateEvidenceReviewStatus(
        itemID: String,
        reviewStatus: EvidenceReviewStatus,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        guard var existingItem = features.evidenceWorkbench.items.first(where: { $0.id == itemID }) else {
            features.sidebar.setError(wordZText("未找到要更新的摘录。", "The excerpt could not be found.", mode: .system))
            return
        }

        if existingItem.reviewStatus == reviewStatus {
            features.library.setStatus(wordZText("摘录状态没有变化。", "The excerpt status is already up to date.", mode: .system))
            features.sidebar.clearError()
            return
        }

        existingItem.reviewStatus = reviewStatus
        await saveEvidenceItem(
            existingItem,
            successMessage: wordZText("已更新摘录状态。", "Updated the excerpt status.", mode: .system),
            features: features
        )
    }

    func saveSelectedEvidenceDetails(features: WorkspaceEvidenceWorkflowContext) async {
        guard var selectedItem = features.evidenceWorkbench.selectedItem else {
            features.sidebar.setError(wordZText("请先选择一个摘录。", "Select an excerpt first.", mode: .system))
            return
        }

        let nextCitationFormat = features.evidenceWorkbench.citationFormatDraft
        let nextCitationStyle = features.evidenceWorkbench.citationStyleDraft
        let nextNote = features.evidenceWorkbench.normalizedText(features.evidenceWorkbench.noteDraft)
        if selectedItem.citationFormat == nextCitationFormat &&
            selectedItem.citationStyle == nextCitationStyle &&
            features.evidenceWorkbench.normalizedText(selectedItem.note) == nextNote
        {
            features.library.setStatus(wordZText("摘录信息没有变化。", "The excerpt details are already up to date.", mode: .system))
            features.sidebar.clearError()
            return
        }

        selectedItem.citationFormat = nextCitationFormat
        selectedItem.citationStyle = nextCitationStyle
        selectedItem.note = nextNote
        await saveEvidenceItem(
            selectedItem,
            successMessage: wordZText("已保存摘录信息。", "Saved the excerpt details.", mode: .system),
            features: features
        )
    }

    func saveSelectedEvidenceNote(features: WorkspaceEvidenceWorkflowContext) async {
        await saveSelectedEvidenceDetails(features: features)
    }

    func moveSelectedEvidenceItem(
        direction: EvidenceWorkbenchMoveDirection,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        guard let selectedItemID = features.evidenceWorkbench.selectedItem?.id else {
            features.sidebar.setError(wordZText("请先选择一个摘录。", "Select an excerpt first.", mode: .system))
            return
        }

        guard let reorderedItems = features.evidenceWorkbench.reorderedItemsMovingSelected(direction) else {
            features.library.setStatus(direction.boundaryStatus(in: .system))
            features.sidebar.clearError()
            return
        }

        await commitEvidenceItemsReplacement(
            reorderedItems,
            preferredSelectionID: selectedItemID,
            successStatus: direction.successStatus(in: .system),
            features: features
        )
    }

    func deleteEvidenceItem(
        itemID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        let item = features.evidenceWorkbench.items.first { $0.id == itemID }
        let itemTitle = item?.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedItemTitle: String
        if let itemTitle, !itemTitle.isEmpty {
            resolvedItemTitle = itemTitle
        } else {
            resolvedItemTitle = wordZText("该摘录", "this excerpt", mode: .system)
        }
        let confirmed = await dialogService.confirm(
                title: wordZText("删除摘录", "Delete Excerpt", mode: .system),
            message: wordZText(
                "确定要删除「\(resolvedItemTitle)」吗？此操作无法撤销。",
                "Delete \"\(resolvedItemTitle)\"? This cannot be undone.",
                mode: .system
            ),
            confirmTitle: wordZText("删除", "Delete", mode: .system),
            preferredRoute: .mainWorkspace
        )
        guard confirmed else { return }

        do {
            try await repository.deleteEvidenceItem(itemID: itemID)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            features.library.setStatus(wordZText("已删除摘录。", "Deleted the excerpt.", mode: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
