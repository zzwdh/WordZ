import Foundation

enum EnginePaths {
    static func isRunningFromAppBundle() -> Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    static func repositoryRoot() throws -> URL {
        if isRunningFromAppBundle() {
            throw NSError(
                domain: "WordZMac.EnginePaths",
                code: 99,
                userInfo: [NSLocalizedDescriptionKey: "当前运行环境是打包后的 App Bundle，没有仓库根目录。"]
            )
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        var candidate = sourceURL.deletingLastPathComponent()

        for _ in 0..<12 {
            let packageJsonURL = candidate.appendingPathComponent("package.json")
            let engineEntryURL = candidate.appendingPathComponent("packages/wordz-engine-js/src/index.mjs")
            let macNativePackageURL = candidate.appendingPathComponent("apps/macos-native/WordZMac/Package.swift")
            if FileManager.default.fileExists(atPath: packageJsonURL.path),
               FileManager.default.fileExists(atPath: engineEntryURL.path),
               FileManager.default.fileExists(atPath: macNativePackageURL.path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if FileManager.default.fileExists(atPath: cwdURL.appendingPathComponent("package.json").path),
           FileManager.default.fileExists(atPath: cwdURL.appendingPathComponent("packages/wordz-engine-js/src/index.mjs").path) {
            return cwdURL
        }

        throw NSError(
            domain: "WordZMac.EnginePaths",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "无法定位仓库根目录。"]
        )
    }

    static func engineEntryURL() throws -> URL {
        let nativeEntry = try nativeScriptURL(named: "native-engine-entry.mjs")
        if FileManager.default.fileExists(atPath: nativeEntry.path) {
            return nativeEntry
        }
        return try repositoryRoot()
            .appendingPathComponent("packages/wordz-engine-js/src/index.mjs")
    }

    static func nativeScriptURL(named name: String) throws -> URL {
        if let bundledScriptsURL = Bundle.main.resourceURL?
            .appendingPathComponent("WordZMacScripts", isDirectory: true),
           FileManager.default.fileExists(atPath: bundledScriptsURL.appendingPathComponent(name).path) {
            return bundledScriptsURL.appendingPathComponent(name)
        }

        return try repositoryRoot()
            .appendingPathComponent("apps/macos-native/WordZMac/Scripts/\(name)")
    }

    static func releaseVersion() -> String {
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundleVersion
        }

        if let repositoryRoot = try? repositoryRoot(),
           let data = try? Data(contentsOf: repositoryRoot.appendingPathComponent("package.json")),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = object["version"] as? String,
           !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return version
        }

        return "native-preview"
    }

    static func nodeExecutableURL() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["WORDZ_NODE_PATH"],
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ]
            .compactMap { $0 }
            .map { URL(fileURLWithPath: $0) }

        if let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return executable
        }

        let lookupProcess = Process()
        let outputPipe = Pipe()
        lookupProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        lookupProcess.arguments = ["node"]
        lookupProcess.standardOutput = outputPipe
        lookupProcess.standardError = Pipe()
        try? lookupProcess.run()
        lookupProcess.waitUntilExit()
        if lookupProcess.terminationStatus == 0,
           let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !output.isEmpty,
           FileManager.default.isExecutableFile(atPath: output) {
            return URL(fileURLWithPath: output)
        }

        throw NSError(
            domain: "WordZMac.EnginePaths",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "未找到可用的 Node.js 可执行文件。请安装 Node.js，或设置 WORDZ_NODE_PATH。"]
        )
    }

    static func defaultUserDataURL() -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let overridePath = environment["WORDZ_NATIVE_USER_DATA_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath, isDirectory: true)
        }

        if !isRunningFromAppBundle(), let repositoryRoot = try? repositoryRoot() {
            return repositoryRoot
                .appendingPathComponent(".wordz-native-user-data", isDirectory: true)
        }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return baseURL.appendingPathComponent("WordZMacNative", isDirectory: true)
    }

    static func runtimeWorkingDirectoryURL() -> URL {
        let userDataURL = defaultUserDataURL()
        try? FileManager.default.createDirectory(at: userDataURL, withIntermediateDirectories: true)
        return userDataURL
    }

    static func startupCrashLogURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-startup-crash.log")
    }
}
