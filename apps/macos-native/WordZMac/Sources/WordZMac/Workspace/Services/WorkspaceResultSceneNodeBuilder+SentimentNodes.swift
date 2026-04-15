import Foundation

extension WorkspaceResultSceneNodeBuilder {
    func makeSentimentNode(from scene: SentimentSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .sentiment, zh: "尚未生成 Sentiment 结果", en: "No sentiment results yet")
        }
        let status = [
            scene.source.title(in: languageMode),
            scene.unit.title(in: languageMode),
            showingStatus(visible: scene.visibleRows, total: scene.filteredRows)
        ].joined(separator: " · ")
        return resultNode(
            for: .sentiment,
            status: status,
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }
}
