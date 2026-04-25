import Foundation

extension WorkspaceResultSceneNodeBuilder {
    func makeTopicsNode(from scene: TopicsSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .topics, zh: "尚未生成 Topics 结果", en: "No Topics results yet")
        }
        let clusterStatus = "\(wordZText("主题", "Topics", mode: languageMode)) \(scene.visibleClusters) / \(scene.totalClusters)"
        let segmentStatus = "\(wordZText("片段", "Segments", mode: languageMode)) \(scene.visibleSegments) / \(scene.totalSegments)"
        return resultNode(
            for: .topics,
            status: "\(clusterStatus) · \(segmentStatus)",
            totalRows: scene.totalSegments,
            visibleRows: scene.visibleSegments,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    func makeKWICNode(from scene: KWICSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .kwic, zh: "尚未生成 KWIC 结果", en: "No KWIC results yet")
        }
        return resultNode(
            for: .kwic,
            status: labeledShowingStatus(labelZh: "关键词", labelEn: "Keyword", value: scene.query, visible: scene.visibleRows, total: scene.totalRows),
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows,
            tableSnapshot: scene.tableSnapshot,
            exportMetadataLines: scene.exportMetadataLines
        )
    }

    func makeCollocateNode(from scene: CollocateSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .collocate, zh: "尚未生成搭配词结果", en: "No collocate results yet")
        }
        return resultNode(
            for: .collocate,
            status: labeledShowingStatus(labelZh: "节点词", labelEn: "Node", value: scene.query, visible: scene.visibleRows, total: scene.totalRows),
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }

    func makeLocatorNode(from scene: LocatorSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .locator, zh: "尚未生成定位结果", en: "No locator results yet")
        }
        return resultNode(
            for: .locator,
            status: labeledShowingStatus(labelZh: "句", labelEn: "Sentence", value: "\(scene.source.sentenceId + 1)", visible: scene.visibleRows, total: scene.totalRows),
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }
}
