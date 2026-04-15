import Foundation

package protocol QuickLookPreviewFilePreparing {
    func prepare(tableSnapshot: QuickLookPreviewTableSnapshot) throws -> String
    func prepare(textDocument: QuickLookPreviewTextDocument) throws -> String
}

package struct QuickLookPreviewTableSnapshot: Equatable, Sendable {
    package let suggestedBaseName: String
    package let headerRow: [String]
    package let rows: [[String]]
    package let metadataLines: [String]

    package init(
        suggestedBaseName: String,
        headerRow: [String],
        rows: [[String]],
        metadataLines: [String] = []
    ) {
        self.suggestedBaseName = suggestedBaseName
        self.headerRow = headerRow
        self.rows = rows
        self.metadataLines = metadataLines
    }
}

package struct QuickLookPreviewTextDocument: Equatable, Sendable {
    package let suggestedName: String
    package let text: String
    package let allowedExtension: String

    package init(suggestedName: String, text: String, allowedExtension: String = "txt") {
        self.suggestedName = suggestedName
        self.text = text
        self.allowedExtension = allowedExtension
    }
}

package struct QuickLookPreviewFileService: QuickLookPreviewFilePreparing {
    private let fileManager: FileManager
    private let rootDirectory: URL

    package init(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory
            ?? fileManager.temporaryDirectory.appendingPathComponent("WordZMac-QuickLook", isDirectory: true)
    }

    package func prepare(tableSnapshot: QuickLookPreviewTableSnapshot) throws -> String {
        let filename = "\(sanitizedBaseName(tableSnapshot.suggestedBaseName, fallback: "wordz-preview")).csv"
        let url = try preparedURL(for: filename)
        try writeCSV(snapshot: tableSnapshot, to: url)
        return url.path
    }

    package func prepare(textDocument: QuickLookPreviewTextDocument) throws -> String {
        let filename = sanitizedTextDocumentName(
            textDocument.suggestedName,
            allowedExtension: textDocument.allowedExtension
        )
        let url = try preparedURL(for: filename)
        try textDocument.text.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    private func writeCSV(snapshot: QuickLookPreviewTableSnapshot, to url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        fileManager.createFile(atPath: url.path, contents: nil)

        let fileHandle = try FileHandle(forWritingTo: url)
        defer { try? fileHandle.close() }

        for line in snapshot.metadataLines {
            try writeCSVRow([line], to: fileHandle)
        }
        if !snapshot.metadataLines.isEmpty {
            try writeCSVRow([], to: fileHandle)
        }

        try writeCSVRow(snapshot.headerRow, to: fileHandle)
        for row in snapshot.rows {
            try writeCSVRow(row, to: fileHandle)
        }
    }

    private func writeCSVRow(_ values: [String], to fileHandle: FileHandle) throws {
        let line = values.map(escapeCSV).joined(separator: ",") + "\n"
        guard let data = line.data(using: .utf8) else {
            throw NSError(
                domain: "WordZHost.QuickLookPreviewFileService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法写入 Quick Look 预览文件。"]
            )
        }
        try fileHandle.write(contentsOf: data)
    }

    private func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func preparedURL(for fileName: String) throws -> URL {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true, attributes: nil)
        return rootDirectory.appendingPathComponent(fileName)
    }

    private func sanitizedTextDocumentName(_ suggestedName: String, allowedExtension: String) -> String {
        let component = URL(fileURLWithPath: suggestedName).lastPathComponent
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "wordz-preview.\(allowedExtension)"
        guard !trimmed.isEmpty else { return fallback }
        let sanitized = trimmed
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
        if sanitized.lowercased().hasSuffix(".\(allowedExtension.lowercased())") {
            return sanitized
        }
        return "\(sanitized).\(allowedExtension)"
    }

    private func sanitizedBaseName(_ suggestedBaseName: String, fallback: String) -> String {
        let component = URL(fileURLWithPath: suggestedBaseName).lastPathComponent
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return trimmed
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
