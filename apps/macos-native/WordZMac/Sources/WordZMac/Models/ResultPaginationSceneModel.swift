import Foundation

struct ResultPaginationSceneModel: Equatable {
    let currentPage: Int
    let totalPages: Int
    let pageSizeLabel: String
    let rangeLabel: String
    let canGoBackward: Bool
    let canGoForward: Bool

    static let singlePage = ResultPaginationSceneModel(
        currentPage: 1,
        totalPages: 1,
        pageSizeLabel: "全部",
        rangeLabel: "0 / 0",
        canGoBackward: false,
        canGoForward: false
    )
}
