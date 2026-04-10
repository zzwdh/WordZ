import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleChiSquareAction(_ action: ChiSquarePageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runChiSquare() }
        case .reset:
            syncResult(.chiSquare) { workspace.chiSquare.handle(action) }
        }
    }
}
