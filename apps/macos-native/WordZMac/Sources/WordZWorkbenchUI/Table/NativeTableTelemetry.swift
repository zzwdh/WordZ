import Foundation
import OSLog

enum NativeTableTelemetry {
    enum TableReloadMode: String, Sendable {
        case none
        case fullColumnsChanged
        case fullMissingColumns
        case fullNoVisibleRows
        case partialVisibleRows
    }

    private static let frameBudgetMilliseconds = 16
    private static let fallbackSubsystem = "com.zzwdh.wordz.native"
    private static let tableLogger = Logger(subsystem: subsystem, category: "Table")

    static func elapsedMilliseconds(since startedAt: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
    }

    static func logApply(
        storageKey: String,
        rowCount: Int,
        columnCount: Int,
        columnsChanged: Bool,
        rowsChanged: Bool,
        selectionChanged: Bool,
        emptinessChanged: Bool,
        densityChanged: Bool,
        headerPinningChanged: Bool,
        reloadMode: TableReloadMode,
        reloadedRowCount: Int,
        durationMs: Int
    ) {
        let shouldLog = columnsChanged
            || rowsChanged
            || selectionChanged
            || emptinessChanged
            || densityChanged
            || headerPinningChanged
            || durationMs >= frameBudgetMilliseconds
        guard shouldLog else { return }

        tableLogger.info(
            "tableApply.completed storageKey=\(storageKey, privacy: .public) rows=\(rowCount) columns=\(columnCount) columnsChanged=\(columnsChanged) rowsChanged=\(rowsChanged) selectionChanged=\(selectionChanged) emptinessChanged=\(emptinessChanged) densityChanged=\(densityChanged) headerPinningChanged=\(headerPinningChanged) reloadMode=\(reloadMode.rawValue, privacy: .public) reloadedRows=\(reloadedRowCount) durationMs=\(durationMs)"
        )
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
