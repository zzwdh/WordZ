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
        guard let effectiveRow = features.sentiment.selectedEffectiveRow else {
            return EvidenceCaptureDraft()
        }

        return EvidenceCaptureDraft(
            note: effectiveRow.reviewNote ?? ""
        )
    }
}
