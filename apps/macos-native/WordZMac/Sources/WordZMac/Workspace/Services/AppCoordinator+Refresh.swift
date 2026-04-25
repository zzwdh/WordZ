import Foundation
import WordZEngine

private let lifecycleLogger = WordZTelemetry.logger(category: "Lifecycle")

@MainActor
extension AppCoordinator {
    func refreshAll(features: WorkspaceFeatureSet) async {
        let startedAt = Date()
        lifecycleLogger.info("refreshAll.started")
        features.shell.isBusy = true
        features.sidebar.setBusy(true)
        defer {
            features.shell.isBusy = false
            features.sidebar.setBusy(false)
        }

        do {
            try await repository.start(userDataURL: EnginePaths.defaultUserDataURL())
            let bootstrapState = try await repository.loadBootstrapState()
            lifecycleLogger.info(
                "refreshAll.bootstrapLoaded corpora=\(bootstrapState.librarySnapshot.corpora.count, privacy: .public) folders=\(bootstrapState.librarySnapshot.folders.count, privacy: .public)"
            )
            bootstrapApplier.apply(bootstrapState, to: features)
            await bootstrapApplier.finalizeRefresh(features: features)
            lifecycleLogger.info(
                "refreshAll.completed durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public)"
            )
        } catch {
            lifecycleLogger.error(
                "refreshAll.failed durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            features.sidebar.setConnectionFailure(error.localizedDescription)
        }
    }
}
