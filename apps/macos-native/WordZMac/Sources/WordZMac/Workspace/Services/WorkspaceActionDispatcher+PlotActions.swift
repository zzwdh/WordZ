import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handlePlotAction(_ action: PlotPageAction) {
        switch action {
        case .run:
            handleWorkspaceIntent(.runAnalysis(.plot))
        case .openKWIC:
            launch { await self.workspace.openPlotKWIC() }
        case .openSourceReader:
            handleWorkspaceIntent(.openSourceReader)
        case .selectRow, .selectMarker:
            syncResult(.plot) { workspace.plot.handle(action) }
        }
    }
}
