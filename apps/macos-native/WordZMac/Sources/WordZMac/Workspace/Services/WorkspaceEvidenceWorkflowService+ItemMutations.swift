import Foundation

@MainActor
extension WorkspaceEvidenceWorkflowService {
    func updateEvidenceReviewStatus(
        itemID: String,
        reviewStatus: EvidenceReviewStatus,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        guard var existingItem = features.evidenceWorkbench.items.first(where: { $0.id == itemID }) else {
            features.sidebar.setError(wordZText("未找到要更新的证据条目。", "The evidence item could not be found.", mode: .system))
            return
        }

        if existingItem.reviewStatus == reviewStatus {
            features.library.setStatus(wordZText("证据条目状态没有变化。", "The evidence item status is already up to date.", mode: .system))
            features.sidebar.clearError()
            return
        }

        existingItem.reviewStatus = reviewStatus
        await saveEvidenceItem(
            existingItem,
            successMessage: wordZText("已更新证据条目状态。", "Updated the evidence review status.", mode: .system),
            features: features
        )
    }

    func saveSelectedEvidenceDetails(features: WorkspaceEvidenceWorkflowContext) async {
        guard var selectedItem = features.evidenceWorkbench.selectedItem else {
            features.sidebar.setError(wordZText("请先选择一个证据条目。", "Select an evidence item first.", mode: .system))
            return
        }

        let nextSectionTitle = features.evidenceWorkbench.normalizedText(features.evidenceWorkbench.sectionDraft)
        let nextClaim = features.evidenceWorkbench.normalizedText(features.evidenceWorkbench.claimDraft)
        let nextTags = features.evidenceWorkbench.normalizedTags(from: features.evidenceWorkbench.tagsDraft)
        let nextCitationFormat = features.evidenceWorkbench.citationFormatDraft
        let nextCitationStyle = features.evidenceWorkbench.citationStyleDraft
        let nextNote = features.evidenceWorkbench.normalizedText(features.evidenceWorkbench.noteDraft)
        if features.evidenceWorkbench.normalizedText(selectedItem.sectionTitle) == nextSectionTitle &&
            features.evidenceWorkbench.normalizedText(selectedItem.claim) == nextClaim &&
            features.evidenceWorkbench.normalizedTags(selectedItem.tags) == nextTags &&
            selectedItem.citationFormat == nextCitationFormat &&
            selectedItem.citationStyle == nextCitationStyle &&
            features.evidenceWorkbench.normalizedText(selectedItem.note) == nextNote
        {
            features.library.setStatus(wordZText("证据整理字段没有变化。", "The evidence details are already up to date.", mode: .system))
            features.sidebar.clearError()
            return
        }

        selectedItem.sectionTitle = nextSectionTitle
        selectedItem.claim = nextClaim
        selectedItem.tags = nextTags
        selectedItem.citationFormat = nextCitationFormat
        selectedItem.citationStyle = nextCitationStyle
        selectedItem.note = nextNote
        await saveEvidenceItem(
            selectedItem,
            successMessage: wordZText("已保存证据整理字段。", "Saved the evidence details.", mode: .system),
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
            features.sidebar.setError(wordZText("请先选择一个证据条目。", "Select an evidence item first.", mode: .system))
            return
        }

        guard let reorderedItems = features.evidenceWorkbench.reorderedItemsMovingSelected(direction) else {
            features.library.setStatus(direction.boundaryStatus(in: .system))
            features.sidebar.clearError()
            return
        }

        do {
            try await repository.replaceEvidenceItems(reorderedItems)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            features.evidenceWorkbench.selectedItemID = selectedItemID
            features.library.setStatus(direction.successStatus(in: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func deleteEvidenceItem(
        itemID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        do {
            try await repository.deleteEvidenceItem(itemID: itemID)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            features.library.setStatus(wordZText("已删除证据条目。", "Deleted the evidence item.", mode: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
