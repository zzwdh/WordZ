import Foundation

import WordZWindowing
@MainActor
extension WorkspaceFlowCoordinator {
    func refreshEvidenceItems(features: WorkspaceFeatureSet) async {
        await evidenceWorkflow.refreshEvidenceItems(features: features.evidenceWorkflowContext)
    }

    func captureCurrentKWICEvidenceItem(
        features: WorkspaceFeatureSet,
        draft: EvidenceCaptureDraft? = nil
    ) async {
        await evidenceWorkflow.captureCurrentKWICEvidenceItem(
            features: features.evidenceWorkflowContext,
            draft: draft
        )
    }

    func captureCurrentLocatorEvidenceItem(
        features: WorkspaceFeatureSet,
        draft: EvidenceCaptureDraft? = nil
    ) async {
        await evidenceWorkflow.captureCurrentLocatorEvidenceItem(
            features: features.evidenceWorkflowContext,
            draft: draft
        )
    }

    func updateEvidenceReviewStatus(
        itemID: String,
        reviewStatus: EvidenceReviewStatus,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.updateEvidenceReviewStatus(
            itemID: itemID,
            reviewStatus: reviewStatus,
            features: features.evidenceWorkflowContext
        )
    }

    func saveSelectedEvidenceDetails(features: WorkspaceFeatureSet) async {
        await evidenceWorkflow.saveSelectedEvidenceDetails(features: features.evidenceWorkflowContext)
    }

    func saveSelectedEvidenceNote(features: WorkspaceFeatureSet) async {
        await saveSelectedEvidenceDetails(features: features)
    }

    func moveSelectedEvidenceItem(
        direction: EvidenceWorkbenchMoveDirection,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.moveSelectedEvidenceItem(
            direction: direction,
            features: features.evidenceWorkflowContext
        )
    }

    func deleteEvidenceItem(
        itemID: String,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.deleteEvidenceItem(itemID: itemID, features: features.evidenceWorkflowContext)
    }

    func captureSourceReaderEvidenceItem(
        sourceKind: EvidenceSourceKind,
        context: SourceReaderLaunchContext,
        anchor: SourceReaderHitAnchor,
        selection: SourceReaderSelection,
        features: WorkspaceFeatureSet,
        draft: EvidenceCaptureDraft? = nil
    ) async {
        await evidenceWorkflow.captureSourceReaderEvidenceItem(
            sourceKind: sourceKind,
            context: context,
            anchor: anchor,
            selection: selection,
            features: features.evidenceWorkflowContext,
            draft: draft
        )
    }

    func copyEvidenceCitation(
        itemID: String,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.copyEvidenceCitation(itemID: itemID, features: features.evidenceWorkflowContext)
    }

    func exportEvidencePacketMarkdown(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await evidenceWorkflow.exportEvidencePacketMarkdown(
            features: features.evidenceWorkflowContext,
            preferredRoute: preferredRoute
        )
    }

    func exportEvidenceJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await evidenceWorkflow.exportEvidenceJSON(
            features: features.evidenceWorkflowContext,
            preferredRoute: preferredRoute
        )
    }
}
