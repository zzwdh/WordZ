import Foundation

@MainActor
final class LocatorPageViewModel: ObservableObject {
    @Published var leftWindow = "5"
    @Published var rightWindow = "5"
    @Published private(set) var source: LocatorSource?
    @Published var scene: LocatorSceneModel?
    @Published private(set) var selectedRowID: String?

    private let sceneBuilder: LocatorSceneBuilder
    private var result: LocatorResult?
    private var pageSize: LocatorPageSize = .fifty
    private var currentPage = 1
    private var visibleColumns: Set<LocatorColumnKey> = Set(LocatorColumnKey.allCases)

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

    func updateSource(_ source: LocatorSource?) {
        guard self.source != source else {
            rebuildScene()
            return
        }
        self.source = source
        result = nil
        currentPage = 1
        selectedRowID = nil
        scene = nil
    }

    func apply(_ result: LocatorResult, source: LocatorSource) {
        self.result = result
        self.source = source
        currentPage = 1
        rebuildScene()
    }

    func handle(_ action: LocatorPageAction) {
        switch action {
        case .run:
            return
        case .changePageSize(let nextPageSize):
            guard pageSize != nextPageSize else { return }
            pageSize = nextPageSize
            currentPage = 1
            rebuildScene()
        case .toggleColumn(let column):
            toggleColumn(column)
        case .selectRow(let rowID):
            selectRow(rowID)
        case .activateRow(let rowID):
            selectRow(rowID)
            if let nextSource = selectedSceneRow?.sourceCandidate {
                source = nextSource
            }
        case .previousPage:
            guard let scene, scene.pagination.canGoBackward else { return }
            currentPage = max(1, currentPage - 1)
            rebuildScene()
        case .nextPage:
            guard let scene, scene.pagination.canGoForward else { return }
            currentPage += 1
            rebuildScene()
        }
    }

    func reset() {
        result = nil
        source = nil
        currentPage = 1
        selectedRowID = nil
        scene = nil
    }

    private func rebuildScene() {
        guard let result, let source else {
            scene = nil
            return
        }
        scene = sceneBuilder.build(
            from: result,
            source: source,
            leftWindow: leftWindowValue,
            rightWindow: rightWindowValue,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns
        )
        currentPage = scene?.pagination.currentPage ?? 1
        if let scene {
            if let selectedRowID, scene.rows.contains(where: { $0.id == selectedRowID }) {
                self.selectedRowID = selectedRowID
            } else {
                self.selectedRowID = scene.rows.first?.id
            }
        } else {
            selectedRowID = nil
        }
    }

    private func toggleColumn(_ column: LocatorColumnKey) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1 else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        rebuildScene()
    }

    private func selectRow(_ rowID: String?) {
        guard let scene else {
            selectedRowID = nil
            return
        }
        guard let rowID else {
            selectedRowID = scene.rows.first?.id
            return
        }
        if scene.rows.contains(where: { $0.id == rowID }) {
            selectedRowID = rowID
        }
    }
}
