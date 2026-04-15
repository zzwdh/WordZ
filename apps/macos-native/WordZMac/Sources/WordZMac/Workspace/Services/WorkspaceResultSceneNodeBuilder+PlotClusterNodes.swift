import Foundation

extension WorkspaceResultSceneNodeBuilder {
    func makePlotNode(from scene: PlotSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .plot, zh: "尚未生成 Plot 结果", en: "No plot results yet")
        }
        return resultNode(
            for: .plot,
            status: filterAwareStatus(
                query: scene.query,
                visible: scene.rows.count,
                total: scene.totalFiles,
                prefix: "\(scene.scope.title(in: languageMode)) · Hits \(scene.totalHits)"
            ),
            totalRows: scene.rows.count,
            visibleRows: scene.rows.count,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }

    func makeClusterNode(from scene: ClusterSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .cluster, zh: "尚未生成 Cluster 结果", en: "No cluster results yet")
        }
        return resultNode(
            for: .cluster,
            status: filterAwareStatus(query: scene.query, visible: scene.visibleRows, total: scene.filteredRows, prefix: "N = \(scene.selectedN)"),
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }
}
