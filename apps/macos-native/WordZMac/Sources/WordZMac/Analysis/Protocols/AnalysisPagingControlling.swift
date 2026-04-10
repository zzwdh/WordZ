import Foundation

@MainActor
protocol AnalysisPagingControlling: AnyObject {
    associatedtype AnalysisPageSize: Equatable

    var pageSize: AnalysisPageSize { get set }
    var currentPage: Int { get set }
    var currentResultRowCountForPaging: Int? { get }

    func rebuildScene()
}

@MainActor
extension AnalysisPagingControlling {
    var currentResultRowCountForPaging: Int? { nil }

    func applyPageSizeChange(_ nextPageSize: AnalysisPageSize) {
        guard pageSize != nextPageSize else { return }
        pageSize = nextPageSize
        currentPage = 1
        rebuildScene()
    }

    func goToPreviousPage(canGoBackward: Bool) {
        guard canGoBackward else { return }
        currentPage = max(1, currentPage - 1)
        rebuildScene()
    }

    func goToNextPage(canGoForward: Bool) {
        guard canGoForward else { return }
        currentPage += 1
        rebuildScene()
    }

    func resetToFirstPageAndRebuild() {
        currentPage = 1
        rebuildScene()
    }
}

@MainActor
extension AnalysisPagingControlling where AnalysisPageSize: InteractiveAllPageSizing {
    func applyPageSizeChange(_ nextPageSize: AnalysisPageSize) {
        let resolvedPageSize = nextPageSize.resolvedInteractivePageSize(totalRows: currentResultRowCountForPaging)
        guard pageSize != resolvedPageSize else { return }
        pageSize = resolvedPageSize
        currentPage = 1
        rebuildScene()
    }
}
