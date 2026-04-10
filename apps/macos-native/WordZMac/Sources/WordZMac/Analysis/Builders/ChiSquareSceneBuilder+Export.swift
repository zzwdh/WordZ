import Foundation

extension ChiSquareSceneBuilder {
    func makeExportTable(
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

    func exportRow(section: String, label: String, value: String, value2: String = "") -> NativeTableRowDescriptor {
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

private extension Array where Element == String {
    subscript(safe index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
