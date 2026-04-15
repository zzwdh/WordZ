import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handlePlotAction(_ action: PlotPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runPlot() }
        case .openKWIC:
            launch { await self.workspace.openPlotKWIC() }
        case .openSourceReader:
            NativeAppCommandCenter.post(.openSourceReader)
        case .selectRow, .selectMarker:
            syncResult(.plot) { workspace.plot.handle(action) }
        }
    }
}
