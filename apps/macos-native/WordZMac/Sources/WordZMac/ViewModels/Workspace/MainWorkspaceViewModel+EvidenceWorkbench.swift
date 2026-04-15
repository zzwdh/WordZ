import Foundation

extension MainWorkspaceViewModel {
    func refreshEvidenceItems() async {
        await flowCoordinator.refreshEvidenceItems(features: features)
    }

    func captureCurrentKWICEvidenceItem() async {
        await flowCoordinator.captureCurrentKWICEvidenceItem(features: features)
    }

    func captureCurrentLocatorEvidenceItem() async {
        await flowCoordinator.captureCurrentLocatorEvidenceItem(features: features)
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

    func saveSelectedEvidenceNote() async {
        await flowCoordinator.saveSelectedEvidenceNote(features: features)
    }

    func deleteEvidenceItem(_ itemID: String) async {
        await flowCoordinator.deleteEvidenceItem(itemID: itemID, features: features)
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
}
