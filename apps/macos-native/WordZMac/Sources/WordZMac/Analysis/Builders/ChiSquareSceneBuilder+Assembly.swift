import Foundation

struct ChiSquareConclusionDetails {
    let significance: String
    let tone: ChiSquareConclusionTone
}

extension ChiSquareSceneBuilder {
    func buildConclusion(for result: ChiSquareResult) -> ChiSquareConclusionDetails {
        if result.significantAt01 {
            return ChiSquareConclusionDetails(significance: "差异极显著（p < 0.01）", tone: .strongEvidence)
        }
        if result.significantAt05 {
            return ChiSquareConclusionDetails(significance: "差异显著（p < 0.05）", tone: .evidence)
        }
        return ChiSquareConclusionDetails(significance: "差异不显著", tone: .noEvidence)
    }

    func buildMetrics(for result: ChiSquareResult) -> [ChiSquareMetricSceneItem] {
        [
            ChiSquareMetricSceneItem(id: "chi", title: "χ²", value: format(result.chiSquare)),
            ChiSquareMetricSceneItem(id: "df", title: "df", value: "\(result.degreesOfFreedom)"),
            ChiSquareMetricSceneItem(id: "p", title: "p 值", value: format(result.pValue)),
            ChiSquareMetricSceneItem(id: "phi", title: "Phi", value: format(result.phi)),
            ChiSquareMetricSceneItem(id: "or", title: "Odds Ratio", value: format(result.oddsRatio)),
            ChiSquareMetricSceneItem(id: "n", title: "总样本", value: "\(result.total)")
        ]
    }

    func buildObservedRows(for result: ChiSquareResult) -> [ChiSquareMatrixSceneRow] {
        result.observed.enumerated().map { index, values in
            ChiSquareMatrixSceneRow(
                id: "observed-\(index)",
                label: index == 0 ? "语料 1" : "语料 2",
                values: values.map { format($0) }
            )
        }
    }

    func buildExpectedRows(for result: ChiSquareResult) -> [ChiSquareMatrixSceneRow] {
        result.expected.enumerated().map { index, values in
            ChiSquareMatrixSceneRow(
                id: "expected-\(index)",
                label: index == 0 ? "语料 1" : "语料 2",
                values: values.map { format($0) }
            )
        }
    }

    func buildRowTotals(for result: ChiSquareResult) -> [ChiSquareDetailSceneItem] {
        result.rowTotals.enumerated().map { index, value in
            ChiSquareDetailSceneItem(
                id: "row-\(index)",
                title: index == 0 ? "语料 1 合计" : "语料 2 合计",
                value: format(value)
            )
        }
    }

    func buildColumnTotals(for result: ChiSquareResult) -> [ChiSquareDetailSceneItem] {
        [
            ChiSquareDetailSceneItem(id: "column-0", title: "目标词合计", value: format(result.colTotals[safe: 0])),
            ChiSquareDetailSceneItem(id: "column-1", title: "非目标词合计", value: format(result.colTotals[safe: 1])),
            ChiSquareDetailSceneItem(id: "column-total", title: "总样本", value: "\(result.total)")
        ]
    }
}
