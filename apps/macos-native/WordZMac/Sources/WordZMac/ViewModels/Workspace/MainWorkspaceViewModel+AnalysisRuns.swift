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
        if sentiment.source == .topicSegments {
            await performResultRun(label: "sentiment", taskKey: .sentiment) {
                await flowCoordinator.runSentiment(features: features)
            }
            return
        }

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
        await performResultRun(label: "chi-square", taskKey: .chiSquare) {
            await flowCoordinator.runChiSquare(features: features)
        }
    }

    func runPlot() async {
        await performResultRun(label: "plot", taskKey: .plot) {
            await flowCoordinator.runPlot(features: features)
        }
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
