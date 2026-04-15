import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleClusterAction(_ action: ClusterPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runCluster() }
        case .openKWIC:
            launch { await self.workspace.openClusterKWIC() }
        case .activateRow(let rowID):
            syncResult(.cluster) { workspace.cluster.handle(.activateRow(rowID)) }
            launch { await self.workspace.openClusterKWIC() }
        case .changeMode, .changeReferenceCorpus, .changeSelectedN, .changeMinFrequency, .changeSort, .sortByColumn, .changePageSize, .changeCaseSensitive, .changePunctuationMode, .toggleColumn, .previousPage, .nextPage, .selectRow:
            syncResult(.cluster) { workspace.cluster.handle(action) }
        }
    }
}
