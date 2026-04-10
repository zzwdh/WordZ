import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleStatsAction(_ action: StatsPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runStats() }
        case .changeNormalizationUnit(let unit):
            workspace.updateFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: unit,
                    rangeMode: workspace.stats.metricDefinition.rangeMode
                )
            )
        case .changeRangeMode(let mode):
            workspace.updateFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: workspace.stats.metricDefinition.normalizationUnit,
                    rangeMode: mode
                )
            )
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage:
            syncResult(.stats) { workspace.stats.handle(action) }
        }
    }
}
