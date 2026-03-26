import Foundation

enum EnginePaths {
    static func repositoryRoot() throws -> URL {
        let sourceURL = URL(fileURLWithPath: #filePath)
        var candidate = sourceURL.deletingLastPathComponent()

        for _ in 0..<12 {
            let packageJsonURL = candidate.appendingPathComponent("package.json")
            let windowsNativeURL = candidate.appendingPathComponent("apps/windows-native")
            if FileManager.default.fileExists(atPath: packageJsonURL.path),
               FileManager.default.fileExists(atPath: windowsNativeURL.path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if FileManager.default.fileExists(atPath: cwdURL.appendingPathComponent("package.json").path) {
            return cwdURL
        }

        throw NSError(
            domain: "WordZMac.EnginePaths",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "无法定位仓库根目录。"]
        )
    }

    static func engineEntryURL() throws -> URL {
        try repositoryRoot()
            .appendingPathComponent("packages/wordz-engine-js/src/index.mjs")
    }

    static func defaultUserDataURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return baseURL.appendingPathComponent("WordZ", isDirectory: true)
    }
}
