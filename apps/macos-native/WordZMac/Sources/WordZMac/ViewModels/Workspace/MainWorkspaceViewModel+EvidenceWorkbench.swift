import Foundation

extension MainWorkspaceViewModel {
    func refreshEvidenceItems() async {
        await flowCoordinator.refreshEvidenceItems(features: features)
    }

    func captureCurrentKWICEvidenceItem(
        draft: EvidenceCaptureDraft? = nil
    ) async {
        await flowCoordinator.captureCurrentKWICEvidenceItem(
            features: features,
            draft: draft
        )
    }

    func captureCurrentLocatorEvidenceItem(
        draft: EvidenceCaptureDraft? = nil
    ) async {
        await flowCoordinator.captureCurrentLocatorEvidenceItem(
            features: features,
            draft: draft
        )
    }

    func captureCurrentSentimentEvidenceItem() async {
        let draft = sentimentEvidenceCaptureDraft()
        guard await openCurrentSourceReader() else { return }
        await captureCurrentSourceReaderEvidenceItem(draft: draft)
    }

    func updateEvidenceReviewStatus(
        itemID: String,
        reviewStatus: EvidenceReviewStatus
    ) async {
        await flowCoordinator.updateEvidenceReviewStatus(
            itemID: itemID,
            reviewStatus: reviewStatus,
            features: features
        )
    }

    func saveSelectedEvidenceDetails() async {
        await flowCoordinator.saveSelectedEvidenceDetails(features: features)
    }

    func saveSelectedEvidenceNote() async {
        await saveSelectedEvidenceDetails()
    }

    func moveSelectedEvidenceItem(_ direction: EvidenceWorkbenchMoveDirection) async {
        await flowCoordinator.moveSelectedEvidenceItem(
            direction: direction,
            features: features
        )
    }

    func moveSelectedEvidenceGroup(_ direction: EvidenceWorkbenchMoveDirection) async {
        await flowCoordinator.moveSelectedEvidenceGroup(
            direction: direction,
            features: features
        )
    }

    func moveEvidenceGroup(
        _ groupID: String,
        direction: EvidenceWorkbenchMoveDirection
    ) async {
        await flowCoordinator.moveEvidenceGroup(
            groupID: groupID,
            direction: direction,
            features: features
        )
    }

    func moveEvidenceGroup(
        _ groupID: String,
        to targetGroupID: String,
        placement: EvidenceWorkbenchGroupInsertPlacement
    ) async {
        await flowCoordinator.moveEvidenceGroup(
            groupID: groupID,
            to: targetGroupID,
            placement: placement,
            features: features
        )
    }

    func assignEvidenceItem(
        _ itemID: String,
        to targetGroupID: String
    ) async {
        await flowCoordinator.assignEvidenceItem(
            itemID: itemID,
            to: targetGroupID,
            features: features
        )
    }

    func createGroupAndAssignEvidenceItem(
        _ itemID: String,
        preferredWindowRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        await flowCoordinator.createGroupAndAssignEvidenceItem(
            itemID: itemID,
            features: features,
            preferredRoute: preferredWindowRoute
        )
    }

    func renameSelectedEvidenceGroup(
        preferredWindowRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        await flowCoordinator.renameSelectedEvidenceGroup(
            features: features,
            preferredRoute: preferredWindowRoute
        )
    }

    func splitSelectedEvidenceGroup(
        preferredWindowRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        await flowCoordinator.splitSelectedEvidenceGroup(
            features: features,
            preferredRoute: preferredWindowRoute
        )
    }

    func mergeSelectedEvidenceGroup(
        preferredWindowRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        await flowCoordinator.mergeSelectedEvidenceGroup(
            features: features,
            preferredRoute: preferredWindowRoute
        )
    }

    func deleteEvidenceItem(_ itemID: String) async {
        await flowCoordinator.deleteEvidenceItem(itemID: itemID, features: features)
    }

    func captureSourceReaderEvidenceItem(
        sourceKind: EvidenceSourceKind,
        context: SourceReaderLaunchContext,
        anchor: SourceReaderHitAnchor,
        selection: SourceReaderSelection,
        draft: EvidenceCaptureDraft? = nil
    ) async {
        await flowCoordinator.captureSourceReaderEvidenceItem(
            sourceKind: sourceKind,
            context: context,
            anchor: anchor,
            selection: selection,
            features: features,
            draft: draft
        )
    }

    func copyEvidenceCitation(itemID: String) async {
        await flowCoordinator.copyEvidenceCitation(itemID: itemID, features: features)
    }

    func exportEvidencePacketMarkdown(
        preferredWindowRoute: NativeWindowRoute? = nil
    ) async {
        await flowCoordinator.exportEvidencePacketMarkdown(
            features: features,
            preferredRoute: preferredWindowRoute
        )
    }

    func exportEvidenceJSON(
        preferredWindowRoute: NativeWindowRoute? = nil
    ) async {
        await flowCoordinator.exportEvidenceJSON(
            features: features,
            preferredRoute: preferredWindowRoute
        )
    }

    private func sentimentEvidenceCaptureDraft() -> EvidenceCaptureDraft {
        guard let rawRow = features.sentiment.selectedResultRow,
              let effectiveRow = features.sentiment.selectedEffectiveRow
        else {
            return EvidenceCaptureDraft()
        }

        let tags = [
            effectiveRow.effectiveLabel.rawValue,
            rawRow.finalLabel.rawValue,
            features.sentiment.selectedDomainPackID.rawValue,
            features.sentiment.selectedRuleProfileID
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: ", ")

        return EvidenceCaptureDraft(
            sectionTitle: wordZText("情感分析", "Sentiment Analysis", mode: .system),
            claim: effectiveRow.effectiveLabel.title(in: .system),
            tagsText: tags,
            note: effectiveRow.reviewNote ?? ""
        )
    }
}
