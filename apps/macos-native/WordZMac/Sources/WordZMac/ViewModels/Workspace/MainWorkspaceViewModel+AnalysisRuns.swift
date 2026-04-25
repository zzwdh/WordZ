import Foundation

private let analysisLogger = WordZTelemetry.logger(category: "Analysis")

private struct ManagedResultRunContext {
    let taskID: UUID
    let startedAt: Date
    let previousTab: WorkspaceDetailTab
}

@MainActor
extension MainWorkspaceViewModel {
    func runStats() async {
        await performResultRun(label: "stats", taskKey: .stats) {
            await flowCoordinator.runStats(features: features)
        }
    }

    func runWord() async {
        await performResultRun(label: "word", taskKey: .word) {
            await flowCoordinator.runWord(features: features)
        }
    }

    func runTokenize() async {
        await performResultRun(label: "tokenize", taskKey: .tokenize) {
            await flowCoordinator.runTokenize(features: features)
        }
    }

    func runTopics() async {
        await performResultRun(label: "topics", taskKey: .topics) {
            await flowCoordinator.runTopics(features: features)
        }
    }

    func runCompare() async {
        await performManagedTask(key: .compare, policy: .replaceLatest) { token in
            await self.runCompare(token: token)
        }
    }

    func runSentiment() async {
        await performResultRun(label: "sentiment", taskKey: .sentiment) {
            await flowCoordinator.runSentiment(features: features)
        }
    }

    func runKeyword() async {
        await performManagedTask(key: .keyword, policy: .replaceLatest) { token in
            await self.runKeyword(token: token)
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

    func importSentimentUserLexiconBundle(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.importSentimentUserLexiconBundle(
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

    func confirmSelectedSentimentRow() async {
        await flowCoordinator.confirmSelectedSentimentRow(features: features)
        syncResultContentSceneGraph(for: .sentiment)
    }

    func overrideSelectedSentimentRow(_ label: SentimentLabel) async {
        await flowCoordinator.overrideSelectedSentimentRow(label, features: features)
        syncResultContentSceneGraph(for: .sentiment)
    }

    func clearSelectedSentimentReview() async {
        await flowCoordinator.clearSelectedSentimentReview(features: features)
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

    func openCompareSentiment(
        preferredRowID: String? = nil,
        openSourceReaderAfterSelection: Bool = false
    ) async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCompareDrilldown(target: .sentiment, features: features)
        guard prepared else { return }
        await runSentiment()
        applySentimentSelection(preferredRowID)
        if openSourceReaderAfterSelection {
            _ = await openCurrentSourceReader()
        }
    }

    func openCompareTopics() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCompareDrilldown(target: .topics, features: features)
        guard prepared else { return }
        await runTopics()
    }

    func openTopicsSentiment(
        scope: TopicsSentimentDrilldownScope,
        preferredRowID: String? = nil,
        openSourceReaderAfterSelection: Bool = false
    ) async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareTopicsSentiment(scope: scope, features: features)
        guard prepared else { return }
        await runSentiment()
        applySentimentSelection(preferredRowID)
        if openSourceReaderAfterSelection {
            _ = await openCurrentSourceReader()
        }
    }

    func openTopicsKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareTopicsKWIC(features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func openCollocateKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCollocateKWIC(features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func runChiSquare() async {
        await performResultRun(label: "chi-square", taskKey: .chiSquare) {
            await flowCoordinator.runChiSquare(features: features)
        }
    }

    func runPlot() async {
        await performResultRun(label: "plot", taskKey: .plot) {
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
        await performManagedTask(key: .kwic, policy: .replaceLatest) { token in
            await self.runKWIC(token: token)
        }
    }

    func runNgram() async {
        await performResultRun(label: "ngram", taskKey: .ngram) {
            await flowCoordinator.runNgram(features: features)
        }
    }

    func runCluster() async {
        await performResultRun(label: "cluster", taskKey: .cluster) {
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
        await performResultRun(label: "collocate", taskKey: .collocate) {
            await flowCoordinator.runCollocate(features: features)
        }
    }

    func runLocator() async {
        await performResultRun(label: "locator", taskKey: .locator) {
            await flowCoordinator.runLocator(features: features)
        }
    }

    private func performResultRun(
        label: String,
        taskKey: WorkspaceRuntimeTaskKey? = nil,
        operation: () async -> Void,
        afterSyncPreparation: (() -> Void)? = nil
    ) async {
        guard !shell.isBusy else {
            analysisLogger.debug("performResultRun.skippedBusy task=\(label, privacy: .public)")
            return
        }
        let startedAt = Date()
        let previousTab = selectedTab
        if let taskKey {
            applyRuntimeTaskState(key: taskKey, isRunning: true)
        }
        defer {
            if let taskKey {
                applyRuntimeTaskState(key: taskKey, isRunning: false)
            }
        }
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

    private func runKWIC(token: WorkspaceRequestToken) async {
        let keyword = kwic.normalizedKeyword
        guard !keyword.isEmpty else {
            sidebar.setError(wordZText("请输入 KWIC 关键词。", "Enter a KWIC keyword first.", mode: .system))
            return
        }

        let previousTab = beginManagedResultRun(
            label: "kwic",
            descriptor: .kwic
        )

        do {
            let corpus = try await performWithoutSceneSyncCallbacks(.navigation) {
                try await flowCoordinator.ensureOpenedCorpus(features: features)
            }
            let result = try await flowCoordinator.analysisWorkflow.repository.runKWIC(
                text: corpus.content,
                keyword: keyword,
                leftWindow: kwic.leftWindowValue,
                rightWindow: kwic.rightWindowValue,
                searchOptions: kwic.searchOptions
            )
            guard await sessionActor.isCurrent(token) else {
                finishManagedResultRunAsDiscarded(context: previousTab, label: "kwic")
                return
            }
            kwic.apply(result)
            syncLocatorSourceFromKWIC()
            completeManagedResultRun(
                context: previousTab,
                label: "kwic",
                descriptor: .kwic,
                selecting: .kwic
            )
        } catch {
            await failManagedResultRun(
                token: token,
                context: previousTab,
                label: "kwic",
                error: error
            )
        }
    }

    private func runCompare(token: WorkspaceRequestToken) async {
        let allCorporaByID = Dictionary(uniqueKeysWithValues: sidebar.librarySnapshot.corpora.map { ($0.id, $0) })
        let selectedCorpora = compare.selectedCorpusItems()
        let referenceCorpusSet = compare.selectedReferenceCorpusSet()
        let referenceSetCorpora = referenceCorpusSet?.corpusIDs.compactMap { allCorporaByID[$0] } ?? []
        let targetCorpora: [LibraryCorpusItem]
        if let referenceCorpusSet {
            let referenceIDs = Set(referenceCorpusSet.corpusIDs)
            targetCorpora = selectedCorpora.filter { !referenceIDs.contains($0.id) }
        } else {
            targetCorpora = selectedCorpora
        }

        guard targetCorpora.count >= 2 || (referenceCorpusSet != nil && !targetCorpora.isEmpty) else {
            sidebar.setError(wordZText("Compare 至少需要选择 2 条目标语料；如果使用命名参考语料集，至少保留 1 条目标语料。", "Compare needs at least 2 target corpora, or at least 1 target corpus when a named reference set is used.", mode: .system))
            return
        }
        if referenceCorpusSet != nil && referenceSetCorpora.isEmpty {
            sidebar.setError(wordZText("当前命名参考语料集没有可用语料。", "The current named reference corpus set has no usable corpora.", mode: .system))
            return
        }

        let previousTab = beginManagedResultRun(
            label: "compare",
            descriptor: .compare
        )

        do {
            let comparisonEntries = try await flowCoordinator.buildComparisonEntries(from: targetCorpora + referenceSetCorpora)
            let result = try await flowCoordinator.analysisWorkflow.repository.runCompare(
                comparisonEntries: comparisonEntries
            )
            guard await sessionActor.isCurrent(token) else {
                finishManagedResultRunAsDiscarded(context: previousTab, label: "compare")
                return
            }
            compare.apply(result)
            completeManagedResultRun(
                context: previousTab,
                label: "compare",
                descriptor: .compare,
                selecting: .compare
            )
        } catch {
            await failManagedResultRun(
                token: token,
                context: previousTab,
                label: "compare",
                error: error
            )
        }
    }

    private func runKeyword(token: WorkspaceRequestToken) async {
        let focusCorpora = keyword.resolvedFocusCorpusItems()
        let referenceCorpora = keyword.resolvedReferenceCorpusItems()
        let importedReferenceParseResult = keyword.referenceSourceKind == .importedWordList
            ? KeywordSuiteAnalyzer.parseImportedReference(keyword.importedReferenceListText)
            : .empty
        let importedReferenceItems = importedReferenceParseResult.items

        guard !focusCorpora.isEmpty else {
            sidebar.setError(wordZText("Keyword Suite 需要先确定 Focus 语料。", "Keyword Suite needs a Focus corpus first.", mode: .system))
            return
        }
        guard !referenceCorpora.isEmpty || !importedReferenceItems.isEmpty else {
            sidebar.setError(wordZText("Keyword Suite 需要显式选择 Reference 语料、命名参考集或导入词表。", "Keyword Suite requires an explicit Reference corpus, named reference set, or imported word list.", mode: .system))
            return
        }

        let focusIDs = Set(focusCorpora.map(\.id))
        let referenceIDs = Set(referenceCorpora.map(\.id))
        if importedReferenceItems.isEmpty,
           focusIDs == referenceIDs,
           focusIDs.count == focusCorpora.count,
           referenceIDs.count == referenceCorpora.count {
            sidebar.setError(wordZText("Focus 与 Reference 不能完全相同。", "Focus and Reference cannot be identical.", mode: .system))
            return
        }

        let focusLabel = keyword.focusSelectionSummary
        let referenceLabel = keyword.referenceSelectionSummary
        let configuration = keyword.suiteConfiguration
        let previousTab = beginManagedResultRun(
            label: "keyword",
            descriptor: .keyword
        )

        do {
            let focusEntries = try await flowCoordinator.analysisWorkflow.buildKeywordRequestEntries(from: focusCorpora)
            let referenceEntries = try await flowCoordinator.analysisWorkflow.buildKeywordRequestEntries(from: referenceCorpora)
            let request = KeywordSuiteRunRequest(
                focusEntries: focusEntries,
                referenceEntries: referenceEntries,
                importedReferenceItems: importedReferenceItems,
                focusLabel: focusLabel,
                referenceLabel: referenceLabel,
                configuration: configuration
            )
            keyword.recordPendingRunConfiguration()
            let result = try await flowCoordinator.analysisWorkflow.repository.runKeywordSuite(request)
            guard await sessionActor.isCurrent(token) else {
                finishManagedResultRunAsDiscarded(context: previousTab, label: "keyword")
                return
            }
            keyword.apply(result)
            completeManagedResultRun(
                context: previousTab,
                label: "keyword",
                descriptor: .keyword,
                selecting: .keyword
            )
        } catch {
            await failManagedResultRun(
                token: token,
                context: previousTab,
                label: "keyword",
                error: error
            )
        }
    }

    private func beginManagedResultRun(
        label: String,
        descriptor: WorkspaceRunTaskDescriptor
    ) -> ManagedResultRunContext {
        let startedAt = Date()
        let previousTab = selectedTab
        analysisLogger.info(
            "performManagedResultRun.started task=\(label, privacy: .public) previousTab=\(previousTab.snapshotValue, privacy: .public)"
        )
        let taskID = taskCenter.beginTask(
            title: descriptor.title(in: .system),
            detail: descriptor.detail(in: .system)
        )
        return ManagedResultRunContext(
            taskID: taskID,
            startedAt: startedAt,
            previousTab: previousTab
        )
    }

    private func completeManagedResultRun(
        context: ManagedResultRunContext,
        label: String,
        descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab
    ) {
        flowCoordinator.completeRun(selecting: tab, features: features)
        syncResultContentSceneGraph(rebuildRootScene: context.previousTab != selectedTab)
        taskCenter.completeTask(
            id: context.taskID,
            detail: descriptor.success(in: .system)
        )
        analysisLogger.info(
            "performManagedResultRun.completed task=\(label, privacy: .public) selectedTab=\(self.selectedTab.snapshotValue, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: context.startedAt), privacy: .public)"
        )
    }

    private func finishManagedResultRunAsDiscarded(
        context: ManagedResultRunContext,
        label: String
    ) {
        taskCenter.completeTask(
            id: context.taskID,
            detail: wordZText("已丢弃过期结果。", "Discarded stale result.", mode: .system)
        )
        analysisLogger.debug(
            "performManagedResultRun.discarded task=\(label, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: context.startedAt), privacy: .public)"
        )
    }

    private func failManagedResultRun(
        token: WorkspaceRequestToken,
        context: ManagedResultRunContext,
        label: String,
        error: Error
    ) async {
        guard await sessionActor.isCurrent(token) else {
            finishManagedResultRunAsDiscarded(context: context, label: label)
            return
        }
        sidebar.setError(error.localizedDescription)
        taskCenter.failTask(id: context.taskID, detail: error.localizedDescription)
        analysisLogger.error(
            "performManagedResultRun.failed task=\(label, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: context.startedAt), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
        )
    }

    private func applySentimentSelection(_ rowID: String?) {
        guard let rowID else { return }
        sentiment.handle(.selectRow(rowID))
        syncResultContentSceneGraph(for: .sentiment)
    }
}
