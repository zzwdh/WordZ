import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WorkspaceDeletionConfirmationTests: XCTestCase {
    func testEvidenceItemDeletionStopsWhenConfirmationIsCancelled() async {
        let repository = FakeWorkspaceRepository()
        let item = makeEvidenceItem(id: "evidence-delete-cancel")
        repository.evidenceItems = [item]
        let dialogService = FakeDialogService()
        dialogService.confirmResult = false
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )
        await workspace.initializeIfNeeded()

        await workspace.deleteEvidenceItem(item.id)

        XCTAssertEqual(dialogService.confirmCallCount, 1)
        XCTAssertEqual(dialogService.confirmPreferredRoute, .evidenceWorkbench)
        XCTAssertEqual(repository.deleteEvidenceItemCallCount, 0)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [item.id])
    }

    func testEvidenceItemDeletionContinuesAfterConfirmation() async {
        let repository = FakeWorkspaceRepository()
        let item = makeEvidenceItem(id: "evidence-delete-confirm")
        repository.evidenceItems = [item]
        let dialogService = FakeDialogService()
        dialogService.confirmResult = true
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )
        await workspace.initializeIfNeeded()

        await workspace.deleteEvidenceItem(item.id)

        XCTAssertEqual(dialogService.confirmCallCount, 1)
        XCTAssertEqual(repository.deleteEvidenceItemCallCount, 1)
        XCTAssertTrue(repository.evidenceItems.isEmpty)
        XCTAssertTrue(workspace.evidenceWorkbench.items.isEmpty)
    }

    func testConcordanceSavedSetDeletionStopsWhenConfirmationIsCancelled() async {
        let repository = FakeWorkspaceRepository()
        let savedSet = makeConcordanceSavedSet(kind: .kwic, rowCount: 2)
        repository.concordanceSavedSets = [savedSet]
        let dialogService = FakeDialogService()
        dialogService.confirmResult = false
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )
        await workspace.initializeIfNeeded()
        workspace.kwic.applySavedSets([savedSet])
        workspace.kwic.selectedSavedSetID = savedSet.id

        await workspace.deleteKWICSavedSet(savedSet.id)

        XCTAssertEqual(dialogService.confirmCallCount, 1)
        XCTAssertEqual(dialogService.confirmPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.deleteConcordanceSavedSetCallCount, 0)
        XCTAssertEqual(repository.concordanceSavedSets.map(\.id), [savedSet.id])
    }
}
