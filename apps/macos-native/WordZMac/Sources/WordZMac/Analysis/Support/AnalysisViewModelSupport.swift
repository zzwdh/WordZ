import Foundation

enum AnalysisViewModelSupport {
    @discardableResult
    static func toggleVisibleColumn<Column: Hashable>(
        _ column: Column,
        in visibleColumns: inout Set<Column>
    ) -> Bool {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1 else { return false }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        return true
    }

    static func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
