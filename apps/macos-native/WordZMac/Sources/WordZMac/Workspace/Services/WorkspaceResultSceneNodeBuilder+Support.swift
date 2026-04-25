import Foundation

extension WorkspaceResultSceneNodeBuilder {
    func emptyNode(for tab: WorkspaceDetailTab, zh: String, en: String) -> WorkspaceResultSceneNode {
        .empty(
            title: tab.displayTitle(in: languageMode),
            status: wordZText(zh, en, mode: languageMode)
        )
    }

    func resultNode(
        for tab: WorkspaceDetailTab,
        status: String,
        totalRows: Int,
        visibleRows: Int,
        table: NativeTableDescriptor,
        tableRows: [NativeTableRowDescriptor],
        tableSnapshot: ResultTableSnapshot? = nil,
        exportMetadataLines: [String] = []
    ) -> WorkspaceResultSceneNode {
        WorkspaceResultSceneNode(
            title: tab.displayTitle(in: languageMode),
            status: status,
            totalRows: totalRows,
            visibleRows: visibleRows,
            hasResult: true,
            table: table,
            tableSnapshot: tableSnapshot ?? ResultTableSnapshot.stable(rows: tableRows),
            exportMetadataLines: exportMetadataLines
        )
    }

    func showingStatus(visible: Int, total: Int, prefix: String? = nil) -> String {
        let showing = wordZText("显示", "Showing", mode: languageMode) + " \(visible) / \(total)"
        guard let prefix, !prefix.isEmpty else { return showing }
        return "\(prefix) · \(showing)"
    }

    func filterAwareStatus(query: String, visible: Int, total: Int, prefix: String? = nil) -> String {
        guard !query.isEmpty else {
            return showingStatus(visible: visible, total: total, prefix: prefix)
        }
        let filter = wordZText("过滤", "Filter", mode: languageMode) + " \(query) · " + showingStatus(visible: visible, total: total)
        guard let prefix, !prefix.isEmpty else { return filter }
        return "\(prefix) · \(filter)"
    }

    func labeledShowingStatus(
        labelZh: String,
        labelEn: String,
        value: String,
        visible: Int,
        total: Int
    ) -> String {
        wordZText(labelZh, labelEn, mode: languageMode) + " \(value) · " + showingStatus(visible: visible, total: total)
    }
}
