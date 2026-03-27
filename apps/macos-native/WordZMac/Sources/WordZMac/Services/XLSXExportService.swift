import Foundation

struct XLSXExportService {
    func write(snapshot: NativeTableExportSnapshot, to path: String) async throws {
        let payload: [String: Any] = [
            "sheetName": sanitizedSheetName(snapshot.suggestedBaseName),
            "headers": snapshot.table.csvHeaderRow(),
            "rows": snapshot.table.csvRows(from: snapshot.rows)
        ]

        let nodeExecutableURL = try EnginePaths.nodeExecutableURL()
        let scriptURL = try EnginePaths.nativeScriptURL(named: "export-xlsx.mjs")
        let runtimeWorkingDirectory = EnginePaths.runtimeWorkingDirectoryURL()
        let payloadURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(".wordz-native-export-\(UUID().uuidString).json")

        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try payloadData.write(to: payloadURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: payloadURL) }

        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = nodeExecutableURL
        process.arguments = [scriptURL.path, payloadURL.path, path]
        process.standardOutput = Pipe()
        process.standardError = stderrPipe
        process.currentDirectoryURL = runtimeWorkingDirectory

        let terminationStatus = try await run(process)
        if terminationStatus != 0 {
            let errorText = String(
                data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "WordZMac.XLSXExportService",
                code: Int(terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: errorText?.isEmpty == false
                        ? errorText!
                        : "Excel 导出失败。"
                ]
            )
        }
    }

    private func run(_ process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { terminated in
                continuation.resume(returning: terminated.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func sanitizedSheetName(_ suggestedBaseName: String) -> String {
        let trimmed = suggestedBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Results" : trimmed
        let invalid = CharacterSet(charactersIn: "[]:*?/\\\\")
        let cleaned = fallback.unicodeScalars.map { invalid.contains($0) ? "_" : Character($0) }
        return String(cleaned.prefix(31))
    }
}
