import Foundation

package enum EnginePaths {
    package static func isRunningFromAppBundle() -> Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    package static func macNativePackageRoot() throws -> URL {
        let sourceURL = URL(fileURLWithPath: #filePath)
        var candidate = sourceURL.deletingLastPathComponent()

        for _ in 0..<8 {
            let packageURL = candidate.appendingPathComponent("Package.swift")
            let executableURL = candidate.appendingPathComponent("Sources/WordZMacExecutable")
            if FileManager.default.fileExists(atPath: packageURL.path),
               FileManager.default.fileExists(atPath: executableURL.path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if FileManager.default.fileExists(atPath: cwdURL.appendingPathComponent("Package.swift").path),
           FileManager.default.fileExists(atPath: cwdURL.appendingPathComponent("Sources/WordZMacExecutable").path) {
            return cwdURL
        }

        throw NSError(
            domain: "WordZMac.EnginePaths",
            code: 100,
            userInfo: [NSLocalizedDescriptionKey: "无法定位 WordZMac SwiftPM 工程根目录。"]
        )
    }

    package static func releaseVersion() -> String {
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundleVersion
        }

        if let packageRoot = try? macNativePackageRoot(),
           let version = versionString(at: packageRoot.appendingPathComponent("VERSION")) {
            return version
        }

        return "native-preview"
    }

    private static func versionString(at url: URL) -> String? {
        guard let rawValue = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let version = rawValue
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return version?.isEmpty == false ? version : nil
    }

    package static func defaultUserDataURL() -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let overridePath = environment["WORDZ_NATIVE_USER_DATA_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath, isDirectory: true)
        }

        if !isRunningFromAppBundle(), let packageRoot = try? macNativePackageRoot() {
            return packageRoot
                .appendingPathComponent(".wordz-native-user-data", isDirectory: true)
        }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return baseURL.appendingPathComponent("WordZMacNative", isDirectory: true)
    }

    package static func runtimeWorkingDirectoryURL() -> URL {
        let userDataURL = defaultUserDataURL()
        try? FileManager.default.createDirectory(at: userDataURL, withIntermediateDirectories: true)
        return userDataURL
    }

    package static func startupCrashLogURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-startup-crash.log")
    }
}
