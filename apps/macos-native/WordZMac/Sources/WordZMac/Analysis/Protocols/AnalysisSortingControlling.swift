import Foundation

@MainActor
protocol AnalysisSortingControlling: AnyObject {
    associatedtype AnalysisSortMode: Equatable

    var sortMode: AnalysisSortMode { get set }
    var currentPage: Int { get set }

    func rebuildScene()
}

@MainActor
extension AnalysisSortingControlling {
    func applySortModeChange(_ nextSort: AnalysisSortMode) {
        guard sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
        rebuildScene()
    }
}
