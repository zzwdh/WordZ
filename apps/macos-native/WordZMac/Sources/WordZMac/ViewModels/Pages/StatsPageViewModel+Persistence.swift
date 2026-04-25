import Foundation

extension StatsPageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyFrequencyMetricDefinition(
            FrequencyMetricDefinition(
                normalizationUnit: snapshot.frequencyNormalizationUnit,
                rangeMode: snapshot.frequencyRangeMode
            )
        )
    }

    func apply(_ result: StatsResult, rebuildSceneAfterApply: Bool = true) {
        self.result = result
        resultGeneration += 1
        currentPage = 1
        invalidateSortedRowsCache()
        if rebuildSceneAfterApply {
            rebuildScene()
        }
    }

    var hasPendingSceneRebuild: Bool {
        result != nil && sceneResultGeneration != resultGeneration
    }

    func rebuildSceneIfNeeded() {
        guard hasPendingSceneRebuild else { return }
        rebuildScene()
    }

    func reset() {
        invalidatePendingSceneBuilds()
        result = nil
        resultGeneration = 0
        sceneResultGeneration = 0
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        definition = .default
        invalidateSortedRowsCache()
        scene = nil
    }
}
