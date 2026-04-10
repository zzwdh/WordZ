import Foundation

extension LocatorPageViewModel {
    func updateSource(_ source: LocatorSource?) {
        guard self.source != source else {
            rebuildScene()
            return
        }
        invalidatePendingSceneBuilds()
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

    func reset() {
        invalidatePendingSceneBuilds()
        result = nil
        source = nil
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        selectedRowID = nil
        scene = nil
    }
}
