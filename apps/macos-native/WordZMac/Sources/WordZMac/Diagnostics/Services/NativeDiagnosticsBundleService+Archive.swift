import Foundation

extension NativeDiagnosticsBundleService {
    func zip(directoryURL: URL, archiveURL: URL) throws {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", directoryURL.path, archiveURL.path]
        process.standardOutput = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw NSError(
                domain: "WordZMac.NativeDiagnosticsBundleService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: stderr.isEmpty ? "无法创建诊断包压缩文件。" : stderr]
            )
        }
    }
}
