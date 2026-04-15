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

    func runSentiment() async {
        await performResultRun(label: "sentiment") {
            await flowCoordinator.runSentiment(features: features)
        }
    }

    func runKeyword() async {
        await performResultRun(label: "keyword") {
            await flowCoordinator.runKeyword(features: features)
        }
    }

    func refreshKeywordSavedLists() async {
        await flowCoordinator.refreshKeywordSavedLists(features: features)
        syncResultContentSceneGraph(for: .keyword)
    }

    func saveKeywordCurrentList() async {
        await flowCoordinator.saveKeywordCurrentList(features: features)
        syncResultContentSceneGraph(for: .keyword)
    }

    func deleteKeywordSavedList(_ listID: String) async {
        await flowCoordinator.deleteKeywordSavedList(listID: listID, features: features)
        syncResultContentSceneGraph(for: .keyword)
    }

    func importKeywordSavedListsJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.importKeywordSavedListsJSON(features: features, preferredRoute: preferredWindowRoute)
        syncResultContentSceneGraph(for: .keyword)
    }

    func exportSelectedKeywordSavedListJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportKeywordSavedListsJSON(
            scope: .selected,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .keyword)
    }

    func exportAllKeywordSavedListsJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportKeywordSavedListsJSON(
            scope: .all,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .keyword)
    }

    func importKeywordReferenceWordList(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.importKeywordReferenceWordList(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .keyword)
    }

    func exportKeywordRowContext(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportKeywordRowContext(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .keyword)
    }

    func exportSentimentSummary(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportSentimentSummary(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .sentiment)
    }

    func exportSentimentStructuredJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportSentimentStructuredJSON(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .sentiment)
    }

    func openKeywordKWIC(scope: KeywordKWICScope) async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareKeywordKWIC(scope: scope, features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func openCompareKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCompareDrilldown(target: .kwic, features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func openCompareCollocate() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCompareDrilldown(target: .collocate, features: features)
        guard prepared else { return }
        await runCollocate()
    }

    func openCollocateKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCollocateKWIC(features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func runChiSquare() async {
        await performResultRun(label: "chi-square") {
            await flowCoordinator.runChiSquare(features: features)
        }
    }

    func runPlot() async {
        await performResultRun(label: "plot") {
            await flowCoordinator.runPlot(features: features)
        }
    }

    func openPlotKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.preparePlotKWIC(features: features)
        guard prepared else { return }
        await runKWIC()
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

    func runCluster() async {
        await performResultRun(label: "cluster") {
            await flowCoordinator.runCluster(features: features)
        }
    }

    func openClusterKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareClusterKWIC(features: features)
        guard prepared else { return }
        await runKWIC()
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
