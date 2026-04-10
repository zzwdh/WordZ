import Foundation

extension WorkspaceResultSceneNodeBuilder {
    func makeWordNode(from scene: WordSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .word, zh: "尚未生成词表结果", en: "No Word results yet")
        }
        return resultNode(
            for: .word,
            status: filterAwareStatus(query: scene.query, visible: scene.visibleRows, total: scene.filteredRows),
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }

    func makeStatsNode(from scene: StatsSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .stats, zh: "尚未生成统计结果", en: "No stats results yet")
        }
        return resultNode(
            for: .stats,
            status: showingStatus(visible: scene.visibleRows, total: scene.totalRows),
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }

    func makeTokenizeNode(from scene: TokenizeSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .tokenize, zh: "尚未生成分词结果", en: "No tokenization results yet")
        }
        return resultNode(
            for: .tokenize,
            status: filterAwareStatus(query: scene.query, visible: scene.visibleTokens, total: scene.filteredTokens),
            totalRows: scene.totalTokens,
            visibleRows: scene.visibleTokens,
            table: scene.table,
            tableRows: scene.tableRows
        )
    }

    func makeNgramNode(from scene: NgramSceneModel?) -> WorkspaceResultSceneNode {
        guard let scene else {
            return emptyNode(for: .ngram, zh: "尚未生成 N-Gram 结果", en: "No N-Gram results yet")
        }
        return resultNode(
            for: .ngram,
            status: filterAwareStatus(query: scene.query, visible: scene.visibleRows, total: scene.filteredRows, prefix: "\(scene.n)-gram"),
            totalRows: scene.totalRows,
            visibleRows: scene.visibleRows,
            table: scene.table,
            tableRows: scene.tableRows,
            exportMetadataLines: scene.exportMetadataLines
        )
    }
}
