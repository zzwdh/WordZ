import Foundation

extension WordPageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyStateChange(rebuildScene: rebuildScene) {
            query = snapshot.searchQuery
            searchOptions = snapshot.searchOptions
            stopwordFilter = snapshot.stopwordFilter
            applyFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: snapshot.frequencyNormalizationUnit,
                    rangeMode: snapshot.frequencyRangeMode
                ),
                rebuildSceneAfterChange: false
            )
        }
    }

    func apply(_ result: StatsResult, rebuildSceneAfterApply: Bool = true) {
        let rebuildSceneAction: (() -> Void)? = rebuildSceneAfterApply ? { self.rebuildScene() } : nil
        applyStateChange(rebuildScene: rebuildSceneAction) {
            self.result = result
            resultGeneration += 1
            currentPage = 1
            invalidateCaches()
        }
        if !rebuildSceneAfterApply {
            sceneBuildRevision += 1
        }
    }

    var hasPendingSceneRebuild: Bool {
        result != nil && sceneResultGeneration != resultGeneration
    }

    func rebuildSceneIfNeeded() {
        guard hasPendingSceneRebuild else { return }
        rebuildScene()
    }

    func applyFrequencyMetricDefinition(
        _ definition: FrequencyMetricDefinition,
        rebuildSceneAfterChange: Bool = true
    ) {
        guard self.definition != definition else { return }
        self.definition = definition
        currentPage = 1
        invalidateSortedRowsCache()
        if rebuildSceneAfterChange {
            rebuildScene()
        }
    }

    func reset() {
        resetState(cancelPendingSceneBuilds: invalidatePendingSceneBuilds) {
            query = ""
            searchOptions = .default
            stopwordFilter = .default
            isEditingStopwords = false
            result = nil
            resultGeneration = 0
            sceneResultGeneration = 0
            currentPage = 1
            visibleColumns = Self.defaultVisibleColumns
            definition = .default
            invalidateCaches()
            scene = nil
        }
    }
}
