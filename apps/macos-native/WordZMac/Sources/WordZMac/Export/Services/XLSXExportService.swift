import Foundation

struct XLSXExportService {
    func write(snapshot: NativeTableExportSnapshot, to path: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            try Self.writeSynchronously(snapshot: snapshot, to: path)
        }.value
    }

    private static func writeSynchronously(snapshot: NativeTableExportSnapshot, to path: String) throws {
        let fileManager = FileManager.default
        let outputURL = URL(fileURLWithPath: path)
        let workingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("wordz-native-xlsx-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workingDirectory) }

        try writeArchiveFiles(snapshot: snapshot, into: workingDirectory)

        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-q", "-r", outputURL.path, "."]
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = Pipe()
        process.standardError = stderrPipe

        let status = try run(process)
        guard status == 0 else {
            let errorText = String(
                data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "WordZMac.XLSXExportService",
                code: Int(status),
                userInfo: [
                    NSLocalizedDescriptionKey: errorText?.isEmpty == false
                        ? errorText!
                        : "Excel 导出失败。"
                ]
            )
        }
    }
}
