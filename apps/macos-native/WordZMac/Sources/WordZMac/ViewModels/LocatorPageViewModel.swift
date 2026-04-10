import Foundation

@MainActor
final class LocatorPageViewModel: ObservableObject, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<LocatorColumnKey> = [.sentenceId, .status, .text]
    @Published var leftWindow = "5"
    @Published var rightWindow = "5"
    @Published var source: LocatorSource?
    @Published var scene: LocatorSceneModel?
    @Published var selectedRowID: String?

    let sceneBuilder: LocatorSceneBuilder
    var result: LocatorResult?
    var pageSize: LocatorPageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<LocatorColumnKey> = LocatorPageViewModel.defaultVisibleColumns
    var sceneBuildRevision = 0

    init(sceneBuilder: LocatorSceneBuilder = LocatorSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var leftWindowValue: Int {
        Int(leftWindow) ?? 5
    }

    var rightWindowValue: Int {
        Int(rightWindow) ?? 5
    }

    var hasSource: Bool {
        currentSource != nil
    }

    var currentSource: LocatorSource? {
        source
    }

    var selectedSceneRow: LocatorSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }
}
