import Foundation

extension TokenizePageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyStateChange(rebuildScene: rebuildScene) {
            query = snapshot.searchQuery
            searchOptions = snapshot.searchOptions
            stopwordFilter = snapshot.stopwordFilter
            applyWorkspaceAnnotationProfile(snapshot.annotationProfile)
            languagePreset = snapshot.tokenizeLanguagePreset
            lemmaStrategy = snapshot.annotationProfile.tokenizeLemmaStrategy
        }
    }

    func apply(_ result: TokenizeResult) {
        applyStateChange(rebuildScene: rebuildScene) {
            self.result = result
            currentPage = 1
            invalidateCaches()
        }
    }

    func reset() {
        resetState(cancelPendingSceneBuilds: invalidatePendingSceneBuilds) {
            query = ""
            searchOptions = .default
            stopwordFilter = .default
            applyWorkspaceAnnotationProfile(.surface)
            languagePreset = .mixedChineseEnglish
            lemmaStrategy = .normalizedSurface
            isEditingStopwords = false
            result = nil
            sortMode = .sequenceAscending
            pageSize = .oneHundred
            currentPage = 1
            visibleColumns = Self.defaultVisibleColumns
            selectedRowID = nil
            invalidateCaches()
            scene = nil
        }
    }
}
