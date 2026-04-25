import Foundation

extension LocatorPageViewModel {
    func rebuildScene() {
        guard let result, let source else {
            invalidatePendingSceneBuilds()
            scene = nil
            selectedRowID = nil
            return
        }
        let revision = beginSceneBuildPass()
        let resultSnapshot = result
        let sourceSnapshot = source
        let leftWindowSnapshot = leftWindowValue
        let rightWindowSnapshot = rightWindowValue
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let rowCount = result.rows.count

        let applyScene: (LocatorSceneModel) -> Void = { nextScene in
            self.scene = nextScene
            self.currentPage = nextScene.pagination.currentPage
            if let currentSelectedRowID = self.selectedRowID,
               nextScene.rows.contains(where: { $0.id == currentSelectedRowID }) {
                self.selectedRowID = currentSelectedRowID
            } else {
                self.selectedRowID = nextScene.rows.first?.id
            }
        }

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let nextScene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "locator", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: result,
                    source: source,
                    leftWindow: leftWindowSnapshot,
                    rightWindow: rightWindowSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot
                )
            }
            applyScene(nextScene)
            return
        }

        AnalysisSceneBuildScheduling.schedule(
            owner: self,
            context: .init(page: "locator", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                try Task.checkCancellation()
                return sceneBuilder.build(
                    from: resultSnapshot,
                    source: sourceSnapshot,
                    leftWindow: leftWindowSnapshot,
                    rightWindow: rightWindowSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot
                )
            },
            apply: { nextScene in
                guard self.isCurrentSceneBuild(revision) else { return false }
                applyScene(nextScene)
                return true
            }
        )
    }
}
