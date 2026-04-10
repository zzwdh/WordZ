import Foundation

extension WorkspaceExportCoordinator {
    func exportActiveScene(
        graph: WorkspaceSceneGraph,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws -> String? {
        guard let snapshot = exportSnapshot(from: graph) else { return nil }
        return try await export(snapshot: snapshot, title: "导出当前结果", preferredRoute: preferredRoute)
    }

    func exportSnapshot(from graph: WorkspaceSceneGraph) -> NativeTableExportSnapshot? {
        switch graph.activeTab {
        case .stats:
            return graph.stats.exportSnapshot
        case .word:
            return graph.word.exportSnapshot
        case .tokenize:
            return graph.tokenize.exportSnapshot
        case .topics:
            return graph.topics.exportSnapshot
        case .compare:
            return graph.compare.exportSnapshot
        case .keyword:
            return graph.keyword.exportSnapshot
        case .chiSquare:
            return graph.chiSquare.exportSnapshot
        case .ngram:
            return graph.ngram.exportSnapshot
        case .kwic:
            return graph.kwic.exportSnapshot
        case .collocate:
            return graph.collocate.exportSnapshot
        case .locator:
            return graph.locator.exportSnapshot
        case .library, .settings:
            return nil
        }
    }
}
