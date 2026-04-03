import Foundation

struct TableExportService {
    func writeCSV(snapshot: NativeTableExportSnapshot, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        FileManager.default.createFile(atPath: url.path, contents: nil)

        let fileHandle = try FileHandle(forWritingTo: url)
        defer { try? fileHandle.close() }

        for line in snapshot.metadataLines {
            try writeCSVRow([line], to: fileHandle)
        }
        if !snapshot.metadataLines.isEmpty {
            try writeCSVRow([], to: fileHandle)
        }

        try writeCSVRow(snapshot.table.csvHeaderRow(), to: fileHandle)
        for row in snapshot.table.csvRows(from: snapshot.rows) {
            try writeCSVRow(row, to: fileHandle)
        }
    }

    private func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
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
