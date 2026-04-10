import Foundation

@MainActor
protocol AnalysisColumnVisibilityControlling: AnyObject {
    associatedtype AnalysisColumn: Hashable

    var visibleColumns: Set<AnalysisColumn> { get set }

    func rebuildScene()
}

@MainActor
extension AnalysisColumnVisibilityControlling {
    func toggleVisibleColumnAndRebuild(_ column: AnalysisColumn) {
        guard AnalysisViewModelSupport.toggleVisibleColumn(column, in: &visibleColumns) else { return }
        rebuildScene()
    }
}
