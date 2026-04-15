import Foundation

@MainActor
final class PlotPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisSelectedRowControlling {
    var isApplyingInputState = false

    @Published var query = "" {
        didSet {
            guard oldValue != query else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var searchOptions = SearchOptionsState.default {
        didSet {
            guard oldValue != searchOptions else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var scene: PlotSceneModel?
    @Published var selectedRowID: String?
    @Published var selectedMarkerID: String?

    var onInputChange: (() -> Void)?
    let sceneBuilder: PlotSceneBuilder
    var result: PlotResult?

    init(sceneBuilder: PlotSceneBuilder = PlotSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var selectedSceneRow: PlotSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    var selectedSceneMarker: PlotSceneMarker? {
        guard let selectedSceneRow else { return nil }
        guard let selectedMarkerID else { return nil }
        return selectedSceneRow.markers.first(where: { $0.id == selectedMarkerID })
    }

    func currentRunRequest(entries: [PlotCorpusEntry], scope: PlotScopeResolution) -> PlotRunRequest {
        PlotRunRequest(
            entries: entries,
            query: normalizedQuery,
            searchOptions: searchOptions,
            scope: scope
        )
    }

    func handle(_ action: PlotPageAction) {
        switch action {
        case .run, .openKWIC, .openSourceReader:
            return
        case .selectRow(let rowID):
            selectRow(rowID)
        case .selectMarker(let rowID, let markerID):
            selectMarker(rowID: rowID, markerID: markerID)
        }
    }

    func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        propagateInputChange(rebuildScene: shouldRebuildScene) {
            rebuildScene()
        }
    }

    func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        let sortedRows = sceneBuilder.sortedRows(from: result)
        syncSelectedRow(within: sortedRows)
        syncSelectedMarker(within: sortedRows)
        scene = sceneBuilder.build(
            from: result,
            sortedRows: sortedRows,
            selectedRowID: selectedRowID,
            selectedMarkerID: selectedMarkerID,
            languageMode: WordZLocalization.shared.effectiveMode
        )
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        isApplyingInputState = true
        defer {
            isApplyingInputState = false
            rebuildScene()
        }
        query = snapshot.plotQuery
        searchOptions = snapshot.plotSearchOptions
    }

    func apply(_ result: PlotResult) {
        isApplyingInputState = true
        defer {
            isApplyingInputState = false
            rebuildScene()
        }
        self.result = result
        query = result.request.query
        searchOptions = result.request.searchOptions
        selectedRowID = nil
        selectedMarkerID = nil
    }

    func reset() {
        isApplyingInputState = true
        defer { isApplyingInputState = false }
        query = ""
        searchOptions = .default
        selectedRowID = nil
        selectedMarkerID = nil
        result = nil
        scene = nil
    }

    func selectRow(_ rowID: String?) {
        guard let scene else {
            selectedRowID = nil
            selectedMarkerID = nil
            return
        }
        if let rowID,
           scene.rows.contains(where: { $0.id == rowID }) {
            selectedRowID = rowID
        } else {
            selectedRowID = scene.rows.first?.id
        }
        syncSelectedSceneMarker(within: scene.rows)
        rebuildScene()
    }

    func selectMarker(rowID: String, markerID: String?) {
        selectedRowID = rowID
        selectedMarkerID = markerID
        rebuildScene()
    }

    private func syncSelectedMarker(within rows: [PlotRow]) {
        guard let selectedRow = selectedRow(from: rows) else {
            selectedMarkerID = nil
            return
        }
        if let selectedMarkerID,
           selectedRow.hitMarkers.contains(where: { $0.id == selectedMarkerID }) {
            return
        }
        selectedMarkerID = nil
    }

    private func syncSelectedSceneMarker(within rows: [PlotSceneRow]) {
        guard let selectedRow = selectedSceneRow(from: rows) else {
            selectedMarkerID = nil
            return
        }
        if let selectedMarkerID,
           selectedRow.markers.contains(where: { $0.id == selectedMarkerID }) {
            return
        }
        selectedMarkerID = nil
    }

    private func selectedRow(from rows: [PlotRow]) -> PlotRow? {
        guard let selectedRowID else { return rows.first }
        return rows.first(where: { $0.id == selectedRowID }) ?? rows.first
    }

    private func selectedSceneRow(from rows: [PlotSceneRow]) -> PlotSceneRow? {
        guard let selectedRowID else { return rows.first }
        return rows.first(where: { $0.id == selectedRowID }) ?? rows.first
    }
}
