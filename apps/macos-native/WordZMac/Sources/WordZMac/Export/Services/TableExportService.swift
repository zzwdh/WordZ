import Foundation

struct TableExportService {
    func makeTSV(snapshot: NativeTableExportSnapshot) -> String {
        let visibleColumns = snapshot.table.visibleColumns
        guard !visibleColumns.isEmpty else { return "" }

        var lines: [String] = []
        lines.reserveCapacity(snapshot.rows.count + 1)
        lines.append(tsvRow(snapshot.table.csvHeaderRow()))
        lines.append(
            contentsOf: snapshot.rows.map { row in
                tsvRow(exportRow(row, visibleColumns: visibleColumns))
            }
        )
        return lines.joined(separator: "\n")
    }

    func writeCSV(snapshot: NativeTableExportSnapshot, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        FileManager.default.createFile(atPath: url.path, contents: nil)

        let fileHandle = try FileHandle(forWritingTo: url)
        defer { try? fileHandle.close() }

        try fileHandle.write(contentsOf: Data([0xEF, 0xBB, 0xBF]))
        try writeCSVRow(snapshot.table.csvHeaderRow(), to: fileHandle)
        let visibleColumns = snapshot.table.visibleColumns
        for row in snapshot.rows {
            try writeCSVRow(exportRow(row, visibleColumns: visibleColumns), to: fileHandle)
        }
    }

    @discardableResult
    func writeMetadataSidecar(snapshot: NativeTableExportSnapshot, forCSVPath path: String) throws -> String {
        let csvURL = URL(fileURLWithPath: path)
        let sidecarURL = csvURL
            .deletingPathExtension()
            .deletingLastPathComponent()
            .appendingPathComponent(csvURL.deletingPathExtension().lastPathComponent + "-metadata.txt")

        let text = metadataSidecarText(snapshot: snapshot)
        try text.write(to: sidecarURL, atomically: true, encoding: .utf8)
        return sidecarURL.path
    }

    private func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func exportRow(
        _ row: NativeTableRowDescriptor,
        visibleColumns: [NativeTableColumnDescriptor]
    ) -> [String] {
        visibleColumns.map { column in
            let cell = row.cell(for: column.id)
            return csvSafeText(
                cell?.stringValue ?? "",
                protectsFormulaLikeText: protectsFormulaLikeText(cell: cell, column: column)
            )
        }
    }

    private func protectsFormulaLikeText(
        cell: NativeTableCellValue?,
        column: NativeTableColumnDescriptor
    ) -> Bool {
        guard !column.isNumeric else { return false }
        switch cell {
        case .integer, .decimal, .boolean:
            return false
        case .text, .custom, .none:
            return true
        }
    }

    private func csvSafeText(
        _ value: String,
        protectsFormulaLikeText: Bool
    ) -> String {
        guard protectsFormulaLikeText else { return value }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return value }
        switch first {
        case "=", "+", "-", "@":
            return "'\(value)"
        default:
            return value
        }
    }

    private func escapeTSV(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private func tsvRow(_ values: [String]) -> String {
        values.map(escapeTSV).joined(separator: "\t")
    }

    private func metadataSidecarText(snapshot: NativeTableExportSnapshot) -> String {
        var lines: [String] = [
            "WordZ Export Metadata",
            "Suggested Base Name: \(snapshot.suggestedBaseName)",
            "Rows: \(snapshot.rows.count)",
            "Columns: \(snapshot.table.visibleColumns.count)"
        ]

        if !snapshot.metadataLines.isEmpty {
            lines.append("")
            lines.append("Analysis Metadata")
            lines.append(contentsOf: snapshot.metadataLines)
        }

        lines.append("")
        lines.append("Data Dictionary")
        lines.append("Column ID\tTitle\tPresentation")
        lines.append(
            contentsOf: snapshot.table.visibleColumns.map { column in
                "\(column.id)\t\(column.title)\t\(column.presentation.exportDescription)"
            }
        )

        return lines.joined(separator: "\n") + "\n"
    }

    private func writeCSVRow(_ values: [String], to fileHandle: FileHandle) throws {
        let line = values.map(escapeCSV).joined(separator: ",") + "\n"
        guard let data = line.data(using: .utf8) else {
            throw NSError(
                domain: "WordZMac.TableExportService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法写入 CSV 数据。"]
            )
        }
        try fileHandle.write(contentsOf: data)
    }
}

private extension NativeTableColumnPresentation {
    var exportDescription: String {
        switch self {
        case .label:
            return "label"
        case .numeric:
            return "numeric"
        case .keyword:
            return "keyword"
        case .contextLeading:
            return "context-leading"
        case .contextTrailing:
            return "context-trailing"
        case .contextCenter:
            return "context-center"
        case .summary:
            return "summary"
        case .custom(let custom):
            return custom.exportDescription
        }
    }
}

private extension NativeTableCustomColumnPresentation {
    var exportDescription: String {
        switch self {
        case .markerStrip:
            return "marker-strip"
        }
    }
}
