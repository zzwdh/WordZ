import Foundation

struct QuickLookPreviewFileService {
    private let fileManager: FileManager
    private let tableExportService: TableExportService
    private let rootDirectory: URL

    init(
        fileManager: FileManager = .default,
        tableExportService: TableExportService = TableExportService(),
        rootDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.tableExportService = tableExportService
        self.rootDirectory = rootDirectory
            ?? fileManager.temporaryDirectory.appendingPathComponent("WordZMac-QuickLook", isDirectory: true)
    }

    func prepare(snapshot: NativeTableExportSnapshot) throws -> String {
        let filename = "\(sanitizedBaseName(snapshot.suggestedBaseName, fallback: "wordz-preview")).csv"
        let url = try preparedURL(for: filename)
        try tableExportService.writeCSV(snapshot: snapshot, to: url.path)
        return url.path
    }

    func prepare(textDocument: PlainTextExportDocument) throws -> String {
        let filename = sanitizedTextDocumentName(textDocument.suggestedName)
        let url = try preparedURL(for: filename)
        try textDocument.text.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    private func preparedURL(for fileName: String) throws -> URL {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true, attributes: nil)
        return rootDirectory.appendingPathComponent(fileName)
    }

    private func sanitizedTextDocumentName(_ suggestedName: String) -> String {
        let component = URL(fileURLWithPath: suggestedName).lastPathComponent
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "wordz-preview.txt"
        guard !trimmed.isEmpty else { return fallback }
        let sanitized = trimmed
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
        if sanitized.lowercased().hasSuffix(".txt") {
            return sanitized
        }
        return "\(sanitized).txt"
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
