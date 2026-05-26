import Foundation

enum AnalysisSceneUpdateScope: Int, Comparable, Sendable {
    case none
    case selectionOnly
    case tableViewport
    case full

    static func < (lhs: AnalysisSceneUpdateScope, rhs: AnalysisSceneUpdateScope) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var requiresSceneBuild: Bool {
        switch self {
        case .none, .selectionOnly:
            return false
        case .tableViewport, .full:
            return true
        }
    }
}

struct AnalysisRowSelectionUpdate: Equatable, Sendable {
    let rowID: String?
    let scope: AnalysisSceneUpdateScope
}

enum AnalysisSceneUpdatePlanner {
    static func scope(for mutation: AnalysisTablePresentationMutation) -> AnalysisSceneUpdateScope {
        switch mutation {
        case .sort, .pageSize, .pageNavigation, .pageReset, .columnVisibility:
            return .tableViewport
        }
    }

    static func rowSelection<Row: Identifiable>(
        currentRowID: String?,
        requestedRowID: String?,
        visibleRows: [Row],
        nilSelectionFallsBackToFirst: Bool = true
    ) -> AnalysisRowSelectionUpdate where Row.ID == String {
        let nextRowID: String?
        if visibleRows.isEmpty {
            nextRowID = nil
        } else if let requestedRowID,
                  visibleRows.contains(where: { $0.id == requestedRowID }) {
            nextRowID = requestedRowID
        } else if nilSelectionFallsBackToFirst {
            nextRowID = visibleRows.first?.id
        } else {
            nextRowID = nil
        }

        return AnalysisRowSelectionUpdate(
            rowID: nextRowID,
            scope: nextRowID == currentRowID ? .none : .selectionOnly
        )
    }
}

@MainActor
extension AnalysisSelectedRowControlling {
    @discardableResult
    func applySelectionOnlyUpdate<Row: Identifiable>(
        _ requestedRowID: String?,
        within visibleRows: [Row],
        nilSelectionFallsBackToFirst: Bool = true
    ) -> AnalysisSceneUpdateScope where Row.ID == String {
        let update = AnalysisSceneUpdatePlanner.rowSelection(
            currentRowID: selectedRowID,
            requestedRowID: requestedRowID,
            visibleRows: visibleRows,
            nilSelectionFallsBackToFirst: nilSelectionFallsBackToFirst
        )
        guard update.scope != .none else { return .none }
        selectedRowID = update.rowID
        return update.scope
    }
}
