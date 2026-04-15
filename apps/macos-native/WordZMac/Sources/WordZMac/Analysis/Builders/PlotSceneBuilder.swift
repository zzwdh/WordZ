import Foundation

struct PlotSceneBuilder {
    func sortedRows(from result: PlotResult) -> [PlotRow] {
        result.rows.sorted { lhs, rhs in
            if lhs.frequency != rhs.frequency {
                return lhs.frequency > rhs.frequency
            }
            if lhs.fileID != rhs.fileID {
                return lhs.fileID < rhs.fileID
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func build(
        from result: PlotResult,
        sortedRows: [PlotRow],
        selectedRowID: String?,
        selectedMarkerID: String?,
        languageMode: AppLanguageMode = .system
    ) -> PlotSceneModel {
        let rows = sortedRows.enumerated().map { index, row in
            PlotSceneRow(
                id: row.id,
                corpusId: row.corpusId,
                rowNumber: index + 1,
                fileID: row.fileID,
                filePath: row.filePath,
                displayName: row.displayName,
                fileTokens: row.fileTokens,
                frequency: row.frequency,
                normalizedFrequency: row.normalizedFrequency,
                normalizedFrequencyText: format(row.normalizedFrequency),
                plotText: markerExportText(row.hitMarkers),
                markers: row.hitMarkers.map { marker in
                    PlotSceneMarker(
                        id: marker.id,
                        sentenceId: marker.sentenceId,
                        tokenIndex: marker.tokenIndex,
                        normalizedPosition: marker.normalizedPosition
                    )
                }
            )
        }

        let tableRows = rows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    PlotColumnKey.row.rawValue: "\(row.rowNumber)",
                    PlotColumnKey.fileID.rawValue: "\(row.fileID)",
                    PlotColumnKey.filePath.rawValue: row.displayPath,
                    PlotColumnKey.fileTokens.rawValue: "\(row.fileTokens)",
                    PlotColumnKey.frequency.rawValue: "\(row.frequency)",
                    PlotColumnKey.normalizedFrequency.rawValue: row.normalizedFrequencyText,
                    PlotColumnKey.plot.rawValue: row.plotText
                ]
            )
        }

        let exportMetadataLines = AnalysisExportMetadataSupport.notes(
            analysisTitle: "Plot",
            languageMode: languageMode,
            visibleRows: rows.count,
            totalRows: result.totalFiles,
            query: result.request.normalizedQuery,
            queryLabel: wordZText("检索词", "Query", mode: languageMode),
            searchOptions: result.request.searchOptions,
            additionalLines: [
                "\(wordZText("范围", "Scope", mode: languageMode)): \(result.request.scope.title(in: languageMode))",
                "\(wordZText("总命中", "Total Hits", mode: languageMode)): \(result.totalHits)",
                "\(wordZText("有命中文件", "Files With Hits", mode: languageMode)): \(result.totalFilesWithHits) / \(result.totalFiles)"
            ]
        )

        return PlotSceneModel(
            query: result.request.normalizedQuery,
            searchOptions: result.request.searchOptions,
            scope: result.request.scope,
            totalHits: result.totalHits,
            totalFilesWithHits: result.totalFilesWithHits,
            totalFiles: result.totalFiles,
            selectedRowID: selectedRowID,
            selectedMarkerID: selectedMarkerID,
            rows: rows,
            table: NativeTableDescriptor(
                storageKey: "plot",
                columns: PlotColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: true,
                        sortIndicator: nil,
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .row || key == .filePath
                    )
                },
                defaultDensity: .compact
            ),
            tableRows: tableRows,
            exportMetadataLines: exportMetadataLines
        )
    }

    private func markerExportText(_ markers: [PlotHitMarker]) -> String {
        markers.map { format($0.normalizedPosition) }.joined(separator: " | ")
    }

    private func presentation(for key: PlotColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .row, .fileID, .fileTokens, .frequency:
            return .numeric(precision: 0)
        case .normalizedFrequency:
            return .numeric(precision: 2)
        case .filePath, .plot:
            return .summary
        }
    }

    private func widthPolicy(for key: PlotColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .row, .fileID, .fileTokens, .frequency, .normalizedFrequency:
            return .numeric
        case .filePath:
            return .summary
        case .plot:
            return .context
        }
    }

    private func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
