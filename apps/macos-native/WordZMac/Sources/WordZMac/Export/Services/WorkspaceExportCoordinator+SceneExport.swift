import Foundation

import WordZWindowing
import WordZExport
extension WorkspaceExportCoordinator {
    func exportActiveScene(
        graph: WorkspaceSceneGraph,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws -> String? {
        guard let snapshot = exportSnapshot(from: graph) else { return nil }
        return try await export(snapshot: snapshot, title: "导出当前结果", preferredRoute: preferredRoute)
    }

    func exportSnapshot(from graph: WorkspaceSceneGraph) -> NativeTableExportSnapshot? {
        graph.activeResultArtifact?.exportSnapshot ?? graph.resultNode(for: graph.activeTab)?.exportSnapshot
    }
}
