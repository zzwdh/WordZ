import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func refreshEvidenceItems(features: WorkspaceFeatureSet) async {
        await evidenceWorkflow.refreshEvidenceItems(features: features)
    }

    func captureCurrentKWICEvidenceItem(features: WorkspaceFeatureSet) async {
        await evidenceWorkflow.captureCurrentKWICEvidenceItem(features: features)
    }

    func captureCurrentLocatorEvidenceItem(features: WorkspaceFeatureSet) async {
        await evidenceWorkflow.captureCurrentLocatorEvidenceItem(features: features)
    }

    func updateEvidenceReviewStatus(
        itemID: String,
        reviewStatus: EvidenceReviewStatus,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.updateEvidenceReviewStatus(
            itemID: itemID,
            reviewStatus: reviewStatus,
            features: features
        )
    }

    func saveSelectedEvidenceNote(features: WorkspaceFeatureSet) async {
        await evidenceWorkflow.saveSelectedEvidenceNote(features: features)
    }

    func deleteEvidenceItem(
        itemID: String,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.deleteEvidenceItem(itemID: itemID, features: features)
    }

    func copyEvidenceCitation(
        itemID: String,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.copyEvidenceCitation(itemID: itemID, features: features)
    }

    func exportEvidencePacketMarkdown(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await evidenceWorkflow.exportEvidencePacketMarkdown(
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func exportEvidenceJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await evidenceWorkflow.exportEvidenceJSON(
            features: features,
            preferredRoute: preferredRoute
        )
    }
}
