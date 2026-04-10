import Foundation

extension WorkspaceResultSceneNodeBuilder {
    func makeCompareNode(from scene: CompareSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .compare, zh: "尚未生成对比结果", en: "No compare results yet")
        }
        return resultNode(
            for: .compare,
            status: filterAwareStatus(query: scene.query, visible: scene.visibleRows, total: scene.filteredRows),
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }

    func makeKeywordNode(from scene: KeywordSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .keyword, zh: "尚未生成关键词结果", en: "No keyword results yet")
        }
        return resultNode(
            for: .keyword,
            status: showingStatus(visible: scene.visibleRows, total: scene.totalRows),
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }

    func makeChiSquareNode(from scene: ChiSquareSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .chiSquare, zh: "尚未生成卡方结果", en: "No chi-square results yet")
        }
        return resultNode(
            for: .chiSquare,
            status: scene.summary,
            totalRows: scene.tableRows.count,
            visibleRows: scene.tableRows.count,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }
}
