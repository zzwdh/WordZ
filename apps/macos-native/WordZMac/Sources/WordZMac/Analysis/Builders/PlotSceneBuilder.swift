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
                columnKey: PlotColumnKey.self
            ) {
                NativeTableCell(.row, "\(row.rowNumber)")
                NativeTableCell(.fileID, "\(row.fileID)")
                NativeTableCell(.filePath, row.displayPath)
                NativeTableCell(.fileTokens, "\(row.fileTokens)")
                NativeTableCell(.frequency, "\(row.frequency)")
                NativeTableCell(.normalizedFrequency, row.normalizedFrequencyText)
                NativeTableCell(
                    .plot,
                    value: .custom(
                        text: row.plotText,
                        presentation: .markerStrip(
                            row.markers.map { marker in
                                NativeTableMarkerValue(
                                    id: marker.id,
                                    normalizedPosition: marker.normalizedPosition,
                                    accessibilityLabel: "Sentence \(marker.sentenceId + 1), token \(marker.tokenIndex + 1)"
                                )
                            }
                        )
                    )
                )
            }
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
                columnKey: PlotColumnKey.self,
                defaultDensity: .compact
            ) {
                for key in PlotColumnKey.allCases {
                    NativeTableColumnSpec(
                        key,
                        title: key.title(in: languageMode),
                        isVisible: true,
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .row || key == .filePath
                    )
                }
            },
            tableRows: tableRows,
            tableSnapshot: ResultTableSnapshot.stable(rows: tableRows),
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
        case .filePath:
            return .summary
        case .plot:
            return .custom(.markerStrip)
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
