import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WorkspaceDeletionConfirmationTests: XCTestCase {
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
