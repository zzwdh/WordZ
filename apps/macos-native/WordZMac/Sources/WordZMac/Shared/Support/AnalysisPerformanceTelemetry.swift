import Foundation

enum AnalysisPerformanceTelemetry {
    struct SceneBuildContext: Sendable {
        let page: String
        let rowCount: Int
        let revision: Int
        let isAsync: Bool
    }

    enum TableReloadMode: String, Sendable {
        case none
        case fullColumnsChanged
        case fullMissingColumns
        case fullNoVisibleRows
        case partialVisibleRows
    }

    private static let frameBudgetMilliseconds = 16
    private static let sceneLogger = WordZTelemetry.logger(category: "SceneBuild")
    private static let tableLogger = WordZTelemetry.logger(category: "Table")

    static func measureSceneBuild<Scene>(
        context: SceneBuildContext,
        build: () -> Scene
    ) -> Scene {
        let startedAt = Date()
        logSceneBuildStarted(context)
        let scene = build()
        logSceneBuildCompleted(context, startedAt: startedAt)
        return scene
    }

    static func logSceneBuildStarted(_ context: SceneBuildContext) {
        sceneLogger.info(
            "sceneBuild.started page=\(context.page, privacy: .public) rows=\(context.rowCount) revision=\(context.revision) mode=\(modeLabel(for: context), privacy: .public)"
        )
    }

    static func logSceneBuildCompleted(
        _ context: SceneBuildContext,
        startedAt: Date
    ) {
        sceneLogger.info(
            "sceneBuild.completed page=\(context.page, privacy: .public) rows=\(context.rowCount) revision=\(context.revision) mode=\(modeLabel(for: context), privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt))"
        )
    }

    static func logSceneBuildDiscarded(
        _ context: SceneBuildContext,
        startedAt: Date
    ) {
        sceneLogger.info(
            "sceneBuild.discarded page=\(context.page, privacy: .public) rows=\(context.rowCount) revision=\(context.revision) mode=\(modeLabel(for: context), privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt))"
        )
    }

    static func logTableApply(
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

    private static func modeLabel(for context: SceneBuildContext) -> String {
        context.isAsync ? "async" : "sync"
    }
}
