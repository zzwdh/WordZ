import Foundation

@MainActor
extension WorkspaceEvidenceWorkflowService {
    func commitEvidenceItemsReplacement(
        _ reorderedItems: [EvidenceItem],
        preferredSelectionID: String?,
        successStatus: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        do {
            try await repository.replaceEvidenceItems(reorderedItems)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            restoreEvidenceSelection(
                preferredItemID: preferredSelectionID,
                features: features
            )
            features.library.setStatus(successStatus)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
