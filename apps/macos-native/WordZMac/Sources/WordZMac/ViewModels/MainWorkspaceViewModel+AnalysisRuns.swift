import Foundation

private let analysisLogger = WordZTelemetry.logger(category: "Analysis")

@MainActor
extension MainWorkspaceViewModel {
    func runStats() async {
        await performResultRun(label: "stats") {
            await flowCoordinator.runStats(features: features)
        }
    }

    func runWord() async {
        await performResultRun(label: "word") {
            await flowCoordinator.runWord(features: features)
        }
    }

    func runTokenize() async {
        await performResultRun(label: "tokenize") {
            await flowCoordinator.runTokenize(features: features)
        }
    }

    func runTopics() async {
        await performResultRun(label: "topics") {
            await flowCoordinator.runTopics(features: features)
        }
    }

    func runCompare() async {
        await performResultRun(label: "compare") {
            await flowCoordinator.runCompare(features: features)
        }
    }

    func runKeyword() async {
        await performResultRun(label: "keyword") {
            await flowCoordinator.runKeyword(features: features)
        }
    }

    func runChiSquare() async {
        await performResultRun(label: "chi-square") {
            await flowCoordinator.runChiSquare(features: features)
        }
    }

    func runKWIC() async {
        await performResultRun(
            label: "kwic",
            operation: { await flowCoordinator.runKWIC(features: features) },
            afterSyncPreparation: { self.syncLocatorSourceFromKWIC() }
        )
    }

    func runNgram() async {
        await performResultRun(label: "ngram") {
            await flowCoordinator.runNgram(features: features)
        }
    }

    func runCollocate() async {
        await performResultRun(label: "collocate") {
            await flowCoordinator.runCollocate(features: features)
        }
    }

    func runLocator() async {
        await performResultRun(label: "locator") {
            await flowCoordinator.runLocator(features: features)
        }
    }

    private func performResultRun(
        label: String,
        operation: () async -> Void,
        afterSyncPreparation: (() -> Void)? = nil
    ) async {
        guard !shell.isBusy else {
            analysisLogger.debug("performResultRun.skippedBusy task=\(label, privacy: .public)")
            return
        }
        let startedAt = Date()
        let previousTab = selectedTab
        analysisLogger.info(
            "performResultRun.started task=\(label, privacy: .public) previousTab=\(previousTab.snapshotValue, privacy: .public)"
        )
        await performWithoutSceneSyncCallbacks(.navigation) {
            await operation()
        }
        afterSyncPreparation?()
        syncResultContentSceneGraph(rebuildRootScene: previousTab != selectedTab)
        analysisLogger.info(
            "performResultRun.completed task=\(label, privacy: .public) selectedTab=\(self.selectedTab.snapshotValue, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public)"
        )
    }
}
