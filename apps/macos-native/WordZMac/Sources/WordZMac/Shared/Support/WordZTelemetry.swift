import Foundation
import OSLog

enum WordZTelemetry {
    private static let fallbackSubsystem = "com.zzwdh.wordz.native"

    static func logger(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }

    static func elapsedMilliseconds(since startedAt: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
    }

    private static var subsystem: String {
        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }
        if let infoBundleIdentifier = Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String,
           !infoBundleIdentifier.isEmpty {
            return infoBundleIdentifier
        }
        return fallbackSubsystem
    }
}
