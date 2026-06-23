import Foundation
import WordZShared

@MainActor
extension MainWorkspaceViewModel {
    func runAnalysis(_ intent: WorkspaceAnalysisIntent) async {
        switch intent {
        case .stats:
            await runStats()
        case .word:
            await runWord()
        case .tokenize:
            await runTokenize()
        case .topics:
            await runTopics()
        case .compare:
            await runCompare()
        case .sentiment:
            await runSentiment()
        case .keyword:
            await runKeyword()
        case .chiSquare:
            await runChiSquare()
        case .plot:
            await runPlot()
        case .ngram:
            await runNgram()
        case .cluster:
            await runCluster()
        case .kwic:
            await runKWIC()
        case .collocate:
            await runCollocate()
        case .locator:
            await runLocator()
        }
    }

    func runStats() async {
        await performManagedTask(key: .stats, policy: .replaceLatest) { token in
            await self.runStats(token: token)
        }
    }

    func runWord() async {
        await performManagedTask(key: .word, policy: .replaceLatest) { _ in
            let token = await self.sessionActor.beginRequest(for: .stats)
            await self.runWord(token: token)
        }
    }

    func runTokenize() async {
        await performManagedTask(key: .tokenize, policy: .replaceLatest) { token in
            await self.runTokenize(token: token)
        }
    }

    func runTopics() async {
        if topics.compareDrilldownContext != nil {
            await performResultRun(label: "topics", taskKey: .topics) {
                await flowCoordinator.runTopics(features: features)
            }
            return
        }

        await performManagedTask(key: .topics, policy: .replaceLatest) { token in
            await self.runTopics(token: token)
        }
    }

    func runCompare() async {
        await performManagedTask(key: .compare, policy: .replaceLatest) { token in
            await self.runCompare(token: token)
        }
    }

    func runSentiment() async {
        await performManagedTask(key: .sentiment, policy: .replaceLatest) { token in
            await self.runSentiment(token: token)
        }
    }

    func runKeyword() async {
        await performManagedTask(key: .keyword, policy: .replaceLatest) { token in
            await self.runKeyword(token: token)
        }
    }

    func runChiSquare() async {
        await performManagedTask(key: .chiSquare, policy: .replaceLatest) { token in
            await self.runChiSquare(token: token)
        }
    }

    func runPlot() async {
        await performManagedTask(key: .plot, policy: .replaceLatest) { token in
            await self.runPlot(token: token)
        }
    }

    func runKWIC() async {
        await performManagedTask(key: .kwic, policy: .replaceLatest) { token in
            await self.runKWIC(token: token)
        }
    }

    func runNgram() async {
        await performManagedTask(key: .ngram, policy: .replaceLatest) { token in
            await self.runNgram(token: token)
        }
    }

    func runCluster() async {
        await performManagedTask(key: .cluster, policy: .replaceLatest) { token in
            await self.runCluster(token: token)
        }
    }

    func runCollocate() async {
        await performManagedTask(key: .collocate, policy: .replaceLatest) { token in
            await self.runCollocate(token: token)
        }
    }

    func runLocator() async {
        await performManagedTask(key: .locator, policy: .replaceLatest) { token in
            await self.runLocator(token: token)
        }
    }

    private func runStats(token: WorkspaceRequestToken) async {
        await performLatestResultRun(
            token: token,
            label: "stats",
            descriptor: .stats,
            selecting: .stats
        ) {
            let corpus = try await self.performWithoutSceneSyncCallbacks(.navigation) {
                try await self.flowCoordinator.ensureOpenedCorpus(features: self.features)
            }
            return try await self.flowCoordinator.analysisWorkflow.repository.runStats(text: corpus.content)
        } apply: { result in
            self.stats.apply(result)
            self.word.apply(result, rebuildSceneAfterApply: false)
        }
    }

    private func runWord(token: WorkspaceRequestToken) async {
        await performLatestResultRun(
            token: token,
            label: "word",
            descriptor: .word,
            selecting: .word
        ) {
            let corpus = try await self.performWithoutSceneSyncCallbacks(.navigation) {
                try await self.flowCoordinator.ensureOpenedCorpus(features: self.features)
            }
            return try await self.flowCoordinator.analysisWorkflow.repository.runStats(text: corpus.content)
        } apply: { result in
            self.stats.apply(result, rebuildSceneAfterApply: false)
            self.word.apply(result)
        }
    }

    private func runTokenize(token: WorkspaceRequestToken) async {
        await performLatestResultRun(
            token: token,
            label: "tokenize",
            descriptor: .tokenize,
            selecting: .tokenize
        ) {
            let corpus = try await self.performWithoutSceneSyncCallbacks(.navigation) {
                try await self.flowCoordinator.ensureOpenedCorpus(features: self.features)
            }
            return try await self.flowCoordinator.analysisWorkflow.repository.runTokenize(text: corpus.content)
        } apply: { result in
            self.tokenize.apply(result)
        }
    }

    private func runChiSquare(token: WorkspaceRequestToken) async {
        let inputs: (Int, Int, Int, Int)
        do {
            inputs = try chiSquare.validatedInputs()
        } catch {
            sidebar.setError(error.localizedDescription)
            return
        }
        let useYates = chiSquare.useYates

        await performLatestResultRun(
            token: token,
            label: "chi-square",
            descriptor: .chiSquare,
            selecting: .chiSquare
        ) {
            return try await self.flowCoordinator.analysisWorkflow.repository.runChiSquare(
                a: inputs.0,
                b: inputs.1,
                c: inputs.2,
                d: inputs.3,
                yates: useYates
            )
        } apply: { result in
            self.chiSquare.apply(result)
        }
    }

    private func runLocator(token: WorkspaceRequestToken) async {
        guard let source = locator.currentSource ?? kwic.primaryLocatorSource else {
            sidebar.setError(wordZText("请先运行 KWIC，Locator 会默认定位第一条结果。", "Run KWIC first so Locator can target the first result by default.", mode: .system))
            return
        }

        await performLatestResultRun(
            token: token,
            label: "locator",
            descriptor: .locator,
            selecting: .locator
        ) {
            let corpus = try await self.performWithoutSceneSyncCallbacks(.navigation) {
                try await self.flowCoordinator.ensureOpenedCorpus(features: self.features)
            }
            return try await self.flowCoordinator.analysisWorkflow.repository.runLocator(
                text: corpus.content,
                sentenceId: source.sentenceId,
                nodeIndex: source.nodeIndex,
                leftWindow: self.locator.leftWindowValue,
                rightWindow: self.locator.rightWindowValue
            )
        } apply: { result in
            self.locator.apply(result, source: source)
        }
    }

    private func runKWIC(token: WorkspaceRequestToken) async {
        let keyword = kwic.normalizedKeyword
        guard !keyword.isEmpty else {
            sidebar.setError(wordZText("请输入 KWIC 关键词。", "Enter a KWIC keyword first.", mode: .system))
            return
        }

        await performLatestResultRun(
            token: token,
            label: "kwic",
            descriptor: .kwic,
            selecting: .kwic
        ) {
            return try await self.flowCoordinator.analysisWorkflow.runSourceAwareKWIC(
                features: self.features,
                keyword: keyword,
                leftWindow: self.kwic.leftWindowValue,
                rightWindow: self.kwic.rightWindowValue,
                searchOptions: self.kwic.searchOptions,
                ensureOpenedCorpus: {
                    try await self.performWithoutSceneSyncCallbacks(.navigation) {
                        try await self.flowCoordinator.ensureOpenedCorpus(features: self.features)
                    }
                }
            )
        } apply: { result in
            self.kwic.apply(result)
            self.syncLocatorSourceFromKWIC()
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

        await performLatestResultRun(
            token: token,
            label: "compare",
            descriptor: .compare,
            selecting: .compare
        ) {
            let comparisonEntries = try await self.flowCoordinator.buildComparisonEntries(from: targetCorpora + referenceSetCorpora)
            return try await self.flowCoordinator.analysisWorkflow.repository.runCompare(
                comparisonEntries: comparisonEntries
            )
        } apply: { result in
            self.compare.apply(result)
        }
    }

    private func runTopics(token: WorkspaceRequestToken) async {
        await performLatestResultRun(
            token: token,
            label: "topics",
            descriptor: .topics,
            selecting: .topics,
            initialProgress: 0
        ) { taskID in
            let corpus = try await self.performWithoutSceneSyncCallbacks(.navigation) {
                try await self.flowCoordinator.ensureOpenedCorpus(features: self.features)
            }
            let options = self.flowCoordinator.topicsWorkflow.topicAnalysisOptions(
                for: self.topics,
                text: corpus.content
            )
            let runFeatures = self.features
            self.flowCoordinator.setBusy(true, features: runFeatures)
            defer { self.flowCoordinator.setBusy(false, features: runFeatures) }

            let analysisTask = Task { () throws -> TopicAnalysisResult in
                if let progressRepository = self.flowCoordinator.analysisWorkflow.repository as? TopicProgressReportingRepository {
                    return try await progressRepository.runTopics(text: corpus.content, options: options) { [weak taskCenter = self.taskCenter] progress in
                        Task { @MainActor in
                            taskCenter?.updateTask(
                                id: taskID,
                                detail: self.flowCoordinator.localizedTopicProgressDetail(progress),
                                progress: progress.progress
                            )
                        }
                    }
                }
                return try await self.flowCoordinator.analysisWorkflow.repository.runTopics(
                    text: corpus.content,
                    options: options
                )
            }
            self.taskCenter.registerCancelHandler(id: taskID) {
                analysisTask.cancel()
            }

            return try await withTaskCancellationHandler {
                try await analysisTask.value
            } onCancel: {
                analysisTask.cancel()
            }
        } apply: { result in
            self.topics.apply(result)
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
            sidebar.setError(wordZText("请先选择要分析的目标语料。", "Choose a focus corpus before running keyword analysis.", mode: .system))
            return
        }
        guard !referenceCorpora.isEmpty || !importedReferenceItems.isEmpty else {
            sidebar.setError(wordZText("请先选择参照语料、参照语料集，或导入参照词表。", "Choose a reference corpus, reference set, or imported word list before running keyword analysis.", mode: .system))
            return
        }

        let focusIDs = Set(focusCorpora.map(\.id))
        let referenceIDs = Set(referenceCorpora.map(\.id))
        if importedReferenceItems.isEmpty,
           focusIDs == referenceIDs,
           focusIDs.count == focusCorpora.count,
           referenceIDs.count == referenceCorpora.count {
            sidebar.setError(wordZText("目标语料和参照语料不能完全相同。", "Focus and Reference cannot be identical.", mode: .system))
            return
        }

        let focusLabel = keyword.focusSelectionSummary
        let referenceLabel = keyword.referenceSelectionSummary
        let configuration = keyword.suiteConfiguration
        await performLatestResultRun(
            token: token,
            label: "keyword",
            descriptor: .keyword,
            selecting: .keyword
        ) {
            let focusEntries = try await self.flowCoordinator.analysisWorkflow.buildKeywordRequestEntries(from: focusCorpora)
            let referenceEntries = try await self.flowCoordinator.analysisWorkflow.buildKeywordRequestEntries(from: referenceCorpora)
            let request = KeywordSuiteRunRequest(
                focusEntries: focusEntries,
                referenceEntries: referenceEntries,
                importedReferenceItems: importedReferenceItems,
                focusLabel: focusLabel,
                referenceLabel: referenceLabel,
                configuration: configuration
            )
            self.keyword.recordPendingRunConfiguration()
            return try await self.flowCoordinator.analysisWorkflow.repository.runKeywordSuite(request)
        } apply: { result in
            self.keyword.apply(result)
        }
    }

}
