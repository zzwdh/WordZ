import Foundation

struct ChiSquareSceneBuilder {
    func build(from result: ChiSquareResult) -> ChiSquareSceneModel {
        let conclusion = buildConclusion(for: result)
        let metrics = buildMetrics(for: result)
        let observedRows = buildObservedRows(for: result)
        let expectedRows = buildExpectedRows(for: result)
        let rowTotals = buildRowTotals(for: result)
        let columnTotals = buildColumnTotals(for: result)
        let summaryDetail = summaryDetailText(for: result)
        let methodLabel = result.yatesCorrection ? "Pearson χ² + Yates 校正" : "Pearson χ²"
        let effectSummary = effectSummaryText(for: result)
        let exportTable = makeExportTable(
            summary: conclusion.significance,
            summaryDetail: summaryDetail,
            methodLabel: methodLabel,
            effectSummary: effectSummary,
            metrics: metrics,
            observedRows: observedRows,
            expectedRows: expectedRows,
            rowTotals: rowTotals,
            columnTotals: columnTotals,
            warnings: result.warnings
        )

        return ChiSquareSceneModel(
            tone: conclusion.tone,
            summary: conclusion.significance,
            summaryDetail: summaryDetail,
            methodLabel: methodLabel,
            effectSummary: effectSummary,
            metrics: metrics,
            observedRows: observedRows,
            expectedRows: expectedRows,
            rowTotals: rowTotals,
            columnTotals: columnTotals,
            warnings: result.warnings,
            table: exportTable.table,
            tableRows: exportTable.rows
        )
    }
}
