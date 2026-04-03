import Foundation

struct ChiSquareSceneBuilder {
    func build(from result: ChiSquareResult) -> ChiSquareSceneModel {
        let significance: String
        let tone: ChiSquareConclusionTone
        if result.significantAt01 {
            significance = "差异极显著（p < 0.01）"
            tone = .strongEvidence
        } else if result.significantAt05 {
            significance = "差异显著（p < 0.05）"
            tone = .evidence
        } else {
            significance = "差异不显著"
            tone = .noEvidence
        }

        let metrics = [
            ChiSquareMetricSceneItem(id: "chi", title: "χ²", value: format(result.chiSquare)),
            ChiSquareMetricSceneItem(id: "df", title: "df", value: "\(result.degreesOfFreedom)"),
            ChiSquareMetricSceneItem(id: "p", title: "p 值", value: format(result.pValue)),
            ChiSquareMetricSceneItem(id: "phi", title: "Phi", value: format(result.phi)),
            ChiSquareMetricSceneItem(id: "or", title: "Odds Ratio", value: format(result.oddsRatio)),
            ChiSquareMetricSceneItem(id: "n", title: "总样本", value: "\(result.total)")
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

        let rowTotals = result.rowTotals.enumerated().map { index, value in
            ChiSquareDetailSceneItem(
                id: "row-\(index)",
                title: index == 0 ? "语料 1 合计" : "语料 2 合计",
                value: format(value)
            )
        }
        let columnTotals = [
            ChiSquareDetailSceneItem(id: "column-0", title: "目标词合计", value: format(result.colTotals[safe: 0])),
            ChiSquareDetailSceneItem(id: "column-1", title: "非目标词合计", value: format(result.colTotals[safe: 1])),
            ChiSquareDetailSceneItem(id: "column-total", title: "总样本", value: "\(result.total)")
        ]

        let summaryDetail = summaryDetailText(for: result)
        let methodLabel = result.yatesCorrection ? "Pearson χ² + Yates 校正" : "Pearson χ²"
        let effectSummary = effectSummaryText(for: result)
        let exportTable = makeExportTable(
            summary: significance,
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
            tone: tone,
            summary: significance,
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

    private func makeExportTable(
        summary: String,
        summaryDetail: String,
        methodLabel: String,
        effectSummary: String,
        metrics: [ChiSquareMetricSceneItem],
        observedRows: [ChiSquareMatrixSceneRow],
        expectedRows: [ChiSquareMatrixSceneRow],
        rowTotals: [ChiSquareDetailSceneItem],
        columnTotals: [ChiSquareDetailSceneItem],
        warnings: [String]
    ) -> (table: NativeTableDescriptor, rows: [NativeTableRowDescriptor]) {
        let table = NativeTableDescriptor(
            storageKey: "chi-square",
            columns: [
                NativeTableColumnDescriptor(id: "section", title: "section", isVisible: true, sortIndicator: nil, presentation: .label, widthPolicy: .standard, isPinned: true),
                NativeTableColumnDescriptor(id: "label", title: "label", isVisible: true, sortIndicator: nil, presentation: .label, widthPolicy: .standard, isPinned: true),
                NativeTableColumnDescriptor(id: "value", title: "value", isVisible: true, sortIndicator: nil, presentation: .label, widthPolicy: .summary),
                NativeTableColumnDescriptor(id: "value2", title: "value2", isVisible: true, sortIndicator: nil, presentation: .label, widthPolicy: .summary)
            ],
            defaultDensity: .compact
        )

        var rows: [NativeTableRowDescriptor] = [
            exportRow(section: "summary", label: "conclusion", value: summary, value2: summaryDetail),
            exportRow(section: "method", label: "test", value: methodLabel),
            exportRow(section: "effect-summary", label: "interpretation", value: effectSummary)
        ]

        rows.append(contentsOf: metrics.map {
            exportRow(section: "metrics", label: $0.title, value: $0.value)
        })

        rows.append(exportRow(section: "observed-matrix", label: "columns", value: "目标词", value2: "非目标词"))
        rows.append(contentsOf: observedRows.map {
            exportRow(
                section: "observed-matrix",
                label: $0.label,
                value: $0.values[safe: 0] ?? "",
                value2: $0.values[safe: 1] ?? ""
            )
        })

        rows.append(exportRow(section: "expected-matrix", label: "columns", value: "目标词", value2: "非目标词"))
        rows.append(contentsOf: expectedRows.map {
            exportRow(
                section: "expected-matrix",
                label: $0.label,
                value: $0.values[safe: 0] ?? "",
                value2: $0.values[safe: 1] ?? ""
            )
        })

        rows.append(contentsOf: rowTotals.map {
            exportRow(section: "totals", label: $0.title, value: $0.value)
        })
        rows.append(contentsOf: columnTotals.map {
            exportRow(section: "totals", label: $0.title, value: $0.value)
        })

        rows.append(contentsOf: warnings.enumerated().map { index, warning in
            exportRow(section: "warnings", label: "warning-\(index + 1)", value: warning)
        })

        return (table, rows)
    }

    private func summaryDetailText(for result: ChiSquareResult) -> String {
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

    private func effectSummaryText(for result: ChiSquareResult) -> String {
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

    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        guard value.isFinite else { return "∞" }
        if abs(value.rounded() - value) < 0.000001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.4f", value)
    }

    private func exportRow(section: String, label: String, value: String, value2: String = "") -> NativeTableRowDescriptor {
        NativeTableRowDescriptor(
            id: "\(section)-\(label)-\(value)-\(value2)",
            values: [
                "section": section,
                "label": label,
                "value": value,
                "value2": value2
            ]
        )
    }
}

private extension Array where Element == Double {
    subscript(safe index: Int) -> Double? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private extension Array where Element == String {
    subscript(safe index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
