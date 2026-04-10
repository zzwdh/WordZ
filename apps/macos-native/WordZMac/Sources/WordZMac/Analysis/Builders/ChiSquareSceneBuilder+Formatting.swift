import Foundation

extension ChiSquareSceneBuilder {
    func summaryDetailText(for result: ChiSquareResult) -> String {
        let significanceLevel: String
        if result.significantAt01 {
            significanceLevel = "结果达到 0.01 水平，语料差异非常稳定。"
        } else if result.significantAt05 {
            significanceLevel = "结果达到 0.05 水平，可认为两组频数存在显著差异。"
        } else {
            significanceLevel = "结果未达到 0.05 水平，当前样本不足以支持显著差异结论。"
        }
        let correction = result.yatesCorrection ? "已启用 Yates 连续性校正。" : "未启用 Yates 连续性校正。"
        return "p = \(format(result.pValue))，\(significanceLevel)\(correction)"
    }

    func effectSummaryText(for result: ChiSquareResult) -> String {
        let phiStrength: String
        let phi = abs(result.phi)
        if phi < 0.1 {
            phiStrength = "效应极弱"
        } else if phi < 0.3 {
            phiStrength = "效应较弱"
        } else if phi < 0.5 {
            phiStrength = "效应中等"
        } else {
            phiStrength = "效应较强"
        }

        let oddsRatioText: String
        if let oddsRatio = result.oddsRatio {
            if oddsRatio > 1 {
                oddsRatioText = "Odds Ratio = \(format(oddsRatio))，语料 1 更倾向出现目标词。"
            } else if oddsRatio < 1 {
                oddsRatioText = "Odds Ratio = \(format(oddsRatio))，语料 2 更倾向出现目标词。"
            } else {
                oddsRatioText = "Odds Ratio = 1，两组出现目标词的倾向接近。"
            }
        } else {
            oddsRatioText = "Odds Ratio 无法计算，通常是某一格频数为 0。"
        }

        return "Phi = \(format(result.phi))，\(phiStrength)。\(oddsRatioText)"
    }

    func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        guard value.isFinite else { return "∞" }
        if abs(value.rounded() - value) < 0.000001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.4f", value)
    }
}

extension Array where Element == Double {
    subscript(safe index: Int) -> Double? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
