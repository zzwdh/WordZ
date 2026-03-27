import Foundation

struct ChiSquareSceneBuilder {
    func build(from result: ChiSquareResult) -> ChiSquareSceneModel {
        let significance: String
        if result.significantAt01 {
            significance = "差异极显著（p < 0.01）"
        } else if result.significantAt05 {
            significance = "差异显著（p < 0.05）"
        } else {
            significance = "差异不显著"
        }

        let metrics = [
            ChiSquareMetricSceneItem(id: "chi", title: "χ²", value: format(result.chiSquare)),
            ChiSquareMetricSceneItem(id: "p", title: "p 值", value: format(result.pValue)),
            ChiSquareMetricSceneItem(id: "phi", title: "Phi", value: format(result.phi)),
            ChiSquareMetricSceneItem(id: "or", title: "Odds Ratio", value: format(result.oddsRatio))
        ]

        let observedRows = result.observed.enumerated().map { index, values in
            ChiSquareMatrixSceneRow(
                id: "observed-\(index)",
                label: index == 0 ? "语料 1" : "语料 2",
                values: values.map { format($0) }
            )
        }
        let expectedRows = result.expected.enumerated().map { index, values in
            ChiSquareMatrixSceneRow(
                id: "expected-\(index)",
                label: index == 0 ? "语料 1" : "语料 2",
                values: values.map { format($0) }
            )
        }

        return ChiSquareSceneModel(
            summary: significance + (result.yatesCorrection ? " · 已启用 Yates 校正" : ""),
            metrics: metrics,
            observedRows: observedRows,
            expectedRows: expectedRows,
            warnings: result.warnings
        )
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        guard value.isFinite else { return "∞" }
        if abs(value.rounded() - value) < 0.000001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.4f", value)
    }
}
