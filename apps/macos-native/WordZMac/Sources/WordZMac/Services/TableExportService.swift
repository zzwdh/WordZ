import Foundation

struct TableExportService {
    func writeCSV(snapshot: NativeTableExportSnapshot, to path: String) throws {
        let header = snapshot.table.csvHeaderRow()
        let rows = snapshot.table.csvRows(from: snapshot.rows)
        let csv = ([header] + rows)
            .map { $0.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\n")
        try csv.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }

    private func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
