import Foundation
import WordZShared

extension SentimentPageViewModel {
    func rebuildScene(from presentationResult: SentimentPresentationResult) {
        let revision = beginSceneBuildPass()
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let thresholdPresetSnapshot = thresholdPreset
        let filterQuerySnapshot = rowFilterQuery
        let labelFilterSnapshot = labelFilter
        let reviewFilterSnapshot = reviewFilter
        let reviewStatusFilterSnapshot = reviewStatusFilter
        let hardCaseSnapshot = showOnlyHardCases
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let selectedRowIDSnapshot = selectedRowID
        let chartKindSnapshot = chartKind
        let metadataLinesSnapshot = exportMetadataLines(
            annotationSummary: annotationState.summary(in: languageModeSnapshot),
            languageMode: languageModeSnapshot
        )
        let rowCount = presentationResult.effectiveRows.count

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let filteredRows = sceneBuilder.filterRows(
                presentationResult.effectiveRows,
                query: filterQuerySnapshot,
                labelFilter: labelFilterSnapshot,
                reviewFilter: reviewFilterSnapshot,
                reviewStatusFilter: reviewStatusFilterSnapshot,
                showOnlyHardCases: hardCaseSnapshot
            )
            syncSelectedRow(within: filteredRows)
            syncSelectedReviewNoteDraft()
            let sortedRows = sceneBuilder.sortRows(filteredRows, mode: sortSnapshot)
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "sentiment", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: presentationResult,
                    thresholdPreset: thresholdPresetSnapshot,
                    filterQuery: filterQuerySnapshot,
                    labelFilter: labelFilterSnapshot,
                    reviewFilter: reviewFilterSnapshot,
                    reviewStatusFilter: reviewStatusFilterSnapshot,
                    showOnlyHardCases: hardCaseSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    selectedRowID: selectedRowID,
                    chartKind: chartKindSnapshot,
                    additionalMetadataLines: metadataLinesSnapshot,
                    languageMode: languageModeSnapshot,
                    filteredRows: filteredRows,
                    sortedRows: sortedRows
                )
            }
            currentPage = scene?.pagination.currentPage ?? 1
            return
        }

        let presentationResultSnapshot = presentationResult
        AnalysisSceneBuildScheduling.schedule(
            owner: self,
            context: .init(page: "sentiment", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                try Task.checkCancellation()
                let filteredRows = sceneBuilder.filterRows(
                    presentationResultSnapshot.effectiveRows,
                    query: filterQuerySnapshot,
                    labelFilter: labelFilterSnapshot,
                    reviewFilter: reviewFilterSnapshot,
                    reviewStatusFilter: reviewStatusFilterSnapshot,
                    showOnlyHardCases: hardCaseSnapshot
                )
                let nextSelectedRowID = Self.resolvedSelectedRowID(
                    selectedRowIDSnapshot,
                    within: filteredRows
                )
                try Task.checkCancellation()
                let sortedRows = sceneBuilder.sortRows(filteredRows, mode: sortSnapshot)
                try Task.checkCancellation()
                let nextScene = sceneBuilder.build(
                    from: presentationResultSnapshot,
                    thresholdPreset: thresholdPresetSnapshot,
                    filterQuery: filterQuerySnapshot,
                    labelFilter: labelFilterSnapshot,
                    reviewFilter: reviewFilterSnapshot,
                    reviewStatusFilter: reviewStatusFilterSnapshot,
                    showOnlyHardCases: hardCaseSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    selectedRowID: nextSelectedRowID,
                    chartKind: chartKindSnapshot,
                    additionalMetadataLines: metadataLinesSnapshot,
                    languageMode: languageModeSnapshot,
                    filteredRows: filteredRows,
                    sortedRows: sortedRows
                )
                return SentimentSceneBuildPayload(
                    selectedRowID: nextSelectedRowID,
                    scene: nextScene
                )
            },
            apply: { (payload: SentimentSceneBuildPayload) in
                guard self.isCurrentSceneBuild(revision) else { return false }
                self.selectedRowID = payload.selectedRowID
                self.scene = payload.scene
                self.currentPage = payload.scene.pagination.currentPage
                self.syncSelectedReviewNoteDraft()
                return true
            }
        )
    }

    nonisolated private static func resolvedSelectedRowID(
        _ selectedRowID: String?,
        within rows: [SentimentEffectiveRow]
    ) -> String? {
        guard !rows.isEmpty else { return nil }
        if let selectedRowID, rows.contains(where: { $0.id == selectedRowID }) {
            return selectedRowID
        }
        return rows.first?.id
    }
}

private struct SentimentSceneBuildPayload {
    let selectedRowID: String?
    let scene: SentimentSceneModel
}
