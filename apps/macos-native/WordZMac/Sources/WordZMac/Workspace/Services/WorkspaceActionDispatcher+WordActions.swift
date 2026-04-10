import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleWordAction(_ action: WordPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runWord() }
        case .changeNormalizationUnit(let unit):
            workspace.updateFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: unit,
                    rangeMode: workspace.word.metricDefinition.rangeMode
                )
            )
        case .changeRangeMode(let mode):
            workspace.updateFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: workspace.word.metricDefinition.normalizationUnit,
                    rangeMode: mode
                )
            )
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage:
            syncResult(.word) { workspace.word.handle(action) }
        }
    }
}
