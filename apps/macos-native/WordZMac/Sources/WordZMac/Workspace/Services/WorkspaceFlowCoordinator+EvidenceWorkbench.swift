import Foundation

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

    func moveSelectedEvidenceGroup(
        direction: EvidenceWorkbenchMoveDirection,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.moveSelectedEvidenceGroup(
            direction: direction,
            features: features.evidenceWorkflowContext
        )
    }

    func moveEvidenceGroup(
        groupID: String,
        direction: EvidenceWorkbenchMoveDirection,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.moveEvidenceGroup(
            groupID: groupID,
            direction: direction,
            features: features.evidenceWorkflowContext
        )
    }

    func moveEvidenceGroup(
        groupID: String,
        to targetGroupID: String,
        placement: EvidenceWorkbenchGroupInsertPlacement,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.moveEvidenceGroup(
            groupID: groupID,
            to: targetGroupID,
            placement: placement,
            features: features.evidenceWorkflowContext
        )
    }

    func assignEvidenceItem(
        itemID: String,
        to targetGroupID: String,
        features: WorkspaceFeatureSet
    ) async {
        await evidenceWorkflow.assignEvidenceItem(
            itemID: itemID,
            to: targetGroupID,
            features: features.evidenceWorkflowContext
        )
    }

    func createGroupAndAssignEvidenceItem(
        itemID: String,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        await evidenceWorkflow.createGroupAndAssignEvidenceItem(
            itemID: itemID,
            features: features.evidenceWorkflowContext,
            preferredRoute: preferredRoute
        )
    }

    func renameSelectedEvidenceGroup(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        await evidenceWorkflow.renameSelectedEvidenceGroup(
            features: features.evidenceWorkflowContext,
            preferredRoute: preferredRoute
        )
    }

    func splitSelectedEvidenceGroup(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        await evidenceWorkflow.splitSelectedEvidenceGroup(
            features: features.evidenceWorkflowContext,
            preferredRoute: preferredRoute
        )
    }

    func mergeSelectedEvidenceGroup(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        await evidenceWorkflow.mergeSelectedEvidenceGroup(
            features: features.evidenceWorkflowContext,
            preferredRoute: preferredRoute
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
