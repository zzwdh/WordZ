import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleChiSquareAction(_ action: ChiSquarePageAction) {
        switch action {
        case .run:
            handleWorkspaceIntent(.runAnalysis(.chiSquare))
        case .reset:
            syncResult(.chiSquare) { workspace.chiSquare.handle(action) }
        }
    }
}
