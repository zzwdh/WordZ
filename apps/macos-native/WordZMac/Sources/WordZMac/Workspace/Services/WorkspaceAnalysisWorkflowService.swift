import Foundation

private let analysisLogger = WordZTelemetry.logger(category: "Analysis")

@MainActor
final class WorkspaceAnalysisWorkflowService {
    let repository: any WorkspaceRepository
    let sessionStore: WorkspaceSessionStore
    let libraryCoordinator: any LibraryCoordinating
    let dialogService: NativeDialogServicing
    let hostActionService: any NativeHostActionServicing
    let exportCoordinator: any WorkspaceExportCoordinating
    let taskCenter: NativeTaskCenter
    let persistenceWorkflow: WorkspacePersistenceWorkflowService
    private var isRunningTopicsAnalysis = false

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        libraryCoordinator: any LibraryCoordinating,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        exportCoordinator: any WorkspaceExportCoordinating,
        taskCenter: NativeTaskCenter,
        persistenceWorkflow: WorkspacePersistenceWorkflowService
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.libraryCoordinator = libraryCoordinator
        self.dialogService = dialogService
        self.hostActionService = hostActionService
        self.exportCoordinator = exportCoordinator
        self.taskCenter = taskCenter
        self.persistenceWorkflow = persistenceWorkflow
    }

    func ensureOpenedCorpus(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws -> OpenedCorpus {
        let corpus = try await libraryCoordinator.ensureOpenedCorpus(
            selectedCorpusID: features.sidebar.selectedCorpusID
        )
        persistenceWorkflow.applyWorkspacePresentation(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        persistenceWorkflow.refreshRecentDocuments(features: features)
        persistenceWorkflow.syncWindowDocumentState(features: features)
        return corpus
    }

    func performWorkspaceRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        features: WorkspaceFeatureSet,
        operation: () async throws -> Void
    ) async {
        let startedAt = Date()
        let taskName = descriptor.title(in: .english)
        analysisLogger.info("run.started task=\(taskName, privacy: .public)")
        let taskID = taskCenter.beginTask(
            title: descriptor.title(in: .system),
            detail: descriptor.detail(in: .system)
        )
        setBusy(true, features: features)
        defer { setBusy(false, features: features) }

        do {
            try await operation()
            features.sidebar.clearError()
            taskCenter.completeTask(
                id: taskID,
                detail: descriptor.success(in: .system)
            )
            analysisLogger.info(
                "run.completed task=\(taskName, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public)"
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            analysisLogger.error(
                "run.failed task=\(taskName, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func performResultRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        operation: () async throws -> Void
    ) async {
        await performWorkspaceRunTask(descriptor, features: features) {
            try await operation()
            self.completeRun(
                selecting: tab,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
        }
    }

    func performOpenedCorpusRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        operation: (OpenedCorpus) async throws -> Void
    ) async {
        await performResultRunTask(
            descriptor,
            selecting: tab,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) {
            let corpus = try await self.ensureOpenedCorpus(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            try await operation(corpus)
        }
    }

    func completeRun(
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) {
        features.shell.selectedTab = tab
        persistenceWorkflow.applyWorkspacePresentation(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        persistenceWorkflow.persistWorkspaceState(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func setBusy(_ isBusy: Bool, features: WorkspaceFeatureSet) {
        features.shell.isBusy = isBusy
        features.sidebar.setBusy(isBusy)
        features.library.setBusy(isBusy)
    }

    func buildComparisonEntries(from selectedCorpora: [LibraryCorpusItem]) async throws -> [CompareRequestEntry] {
        var entries: [CompareRequestEntry] = []
        var seenCorpusIDs: Set<String> = []
        for corpus in selectedCorpora {
            guard seenCorpusIDs.insert(corpus.id).inserted else { continue }
            let opened = try await repository.openSavedCorpus(corpusId: corpus.id)
            entries.append(
                CompareRequestEntry(
                    corpusId: corpus.id,
                    corpusName: corpus.name,
                    folderId: corpus.folderId,
                    folderName: corpus.folderName,
                    sourceType: opened.sourceType,
                    content: opened.content
                )
            )
        }
        return entries
    }

    func localizedTopicProgressDetail(_ progress: TopicAnalysisProgress) -> String {
        switch progress.stage {
        case .preparing:
            return wordZText("正在加载 Topics 模型…", "Loading the Topics model…", mode: .system)
        case .segmenting:
            return wordZText("正在切分英文段落…", "Segmenting English paragraphs…", mode: .system)
        case .embedding:
            return wordZText("正在生成段落向量…", "Embedding paragraph vectors…", mode: .system)
        case .clustering:
            return wordZText("正在聚类主题…", "Clustering topics…", mode: .system)
        case .summarizing:
            return wordZText("正在生成关键词与代表片段…", "Building keywords and representative segments…", mode: .system)
        }
    }

    func runStats(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        await performOpenedCorpusRunTask(
            .stats,
            selecting: .stats,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) { corpus in
            let result = try await self.repository.runStats(text: corpus.content)
            features.stats.apply(result)
            features.word.apply(result, rebuildSceneAfterApply: false)
        }
    }

    func runWord(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        await performOpenedCorpusRunTask(
            .word,
            selecting: .word,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) { corpus in
            let result = try await self.repository.runStats(text: corpus.content)
            features.stats.apply(result, rebuildSceneAfterApply: false)
            features.word.apply(result)
        }
    }

    func runTokenize(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        await performOpenedCorpusRunTask(
            .tokenize,
            selecting: .tokenize,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) { corpus in
            let result = try await self.repository.runTokenize(text: corpus.content)
            features.tokenize.apply(result)
        }
    }

    func runKWIC(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let keyword = features.kwic.normalizedKeyword
        guard !keyword.isEmpty else {
            features.sidebar.setError(wordZText("请输入 KWIC 关键词。", "Enter a KWIC keyword first.", mode: .system))
            return
        }

        await performOpenedCorpusRunTask(
            .kwic,
            selecting: .kwic,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) { corpus in
            let result = try await self.repository.runKWIC(
                text: corpus.content,
                keyword: keyword,
                leftWindow: features.kwic.leftWindowValue,
                rightWindow: features.kwic.rightWindowValue,
                searchOptions: features.kwic.searchOptions
            )
            features.kwic.apply(result)
        }
    }

    func runNgram(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        await performOpenedCorpusRunTask(
            .ngram,
            selecting: .ngram,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) { corpus in
            let result = try await self.repository.runNgram(
                text: corpus.content,
                n: features.ngram.ngramSizeValue
            )
            features.ngram.apply(result)
        }
    }

    func runCollocate(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let keyword = features.collocate.normalizedKeyword
        guard !keyword.isEmpty else {
            features.sidebar.setError(wordZText("请输入 Collocate 节点词。", "Enter a Collocate node word first.", mode: .system))
            return
        }

        await performOpenedCorpusRunTask(
            .collocate,
            selecting: .collocate,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) { corpus in
            features.collocate.recordPendingRunConfiguration()
            let result = try await self.repository.runCollocate(
                text: corpus.content,
                keyword: keyword,
                leftWindow: features.collocate.leftWindowValue,
                rightWindow: features.collocate.rightWindowValue,
                minFreq: features.collocate.minFreqValue,
                searchOptions: features.collocate.searchOptions
            )
            features.collocate.apply(result)
        }
    }

    func runLocator(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        guard let source = features.locator.currentSource ?? features.kwic.primaryLocatorSource else {
            features.sidebar.setError(wordZText("请先运行 KWIC，Locator 会默认定位第一条结果。", "Run KWIC first so Locator can target the first result by default.", mode: .system))
            return
        }

        await performOpenedCorpusRunTask(
            .locator,
            selecting: .locator,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) { corpus in
            let result = try await self.repository.runLocator(
                text: corpus.content,
                sentenceId: source.sentenceId,
                nodeIndex: source.nodeIndex,
                leftWindow: features.locator.leftWindowValue,
                rightWindow: features.locator.rightWindowValue
            )
            features.locator.apply(result, source: source)
        }
    }

    func runCompare(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let allCorporaByID = Dictionary(uniqueKeysWithValues: features.sidebar.librarySnapshot.corpora.map { ($0.id, $0) })
        let selectedCorpora = features.compare.selectedCorpusItems()
        let referenceCorpusSet = features.compare.selectedReferenceCorpusSet()
        let referenceSetCorpora = referenceCorpusSet?.corpusIDs.compactMap { allCorporaByID[$0] } ?? []
        let targetCorpora: [LibraryCorpusItem]
        if let referenceCorpusSet {
            let referenceIDs = Set(referenceCorpusSet.corpusIDs)
            targetCorpora = selectedCorpora.filter { !referenceIDs.contains($0.id) }
        } else {
            targetCorpora = selectedCorpora
        }

        guard targetCorpora.count >= 2 || (referenceCorpusSet != nil && !targetCorpora.isEmpty) else {
            features.sidebar.setError(wordZText("Compare 至少需要选择 2 条目标语料；如果使用命名参考语料集，至少保留 1 条目标语料。", "Compare needs at least 2 target corpora, or at least 1 target corpus when a named reference set is used.", mode: .system))
            return
        }
        if referenceCorpusSet != nil && referenceSetCorpora.isEmpty {
            features.sidebar.setError(wordZText("当前命名参考语料集没有可用语料。", "The current named reference corpus set has no usable corpora.", mode: .system))
            return
        }

        await performResultRunTask(
            .compare,
            selecting: .compare,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) {
            let comparisonEntries = try await self.buildComparisonEntries(from: targetCorpora + referenceSetCorpora)
            let result = try await self.repository.runCompare(comparisonEntries: comparisonEntries)
            features.compare.apply(result)
        }
    }

    func runKeyword(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let focusCorpora = features.keyword.resolvedFocusCorpusItems()
        let referenceCorpora = features.keyword.resolvedReferenceCorpusItems()
        let importedReferenceParseResult = features.keyword.referenceSourceKind == .importedWordList
            ? KeywordSuiteAnalyzer.parseImportedReference(features.keyword.importedReferenceListText)
            : .empty
        let importedReferenceItems = importedReferenceParseResult.items

        guard !focusCorpora.isEmpty else {
            features.sidebar.setError(wordZText("Keyword Suite 需要先确定 Focus 语料。", "Keyword Suite needs a Focus corpus first.", mode: .system))
            return
        }
        guard !referenceCorpora.isEmpty || !importedReferenceItems.isEmpty else {
            features.sidebar.setError(wordZText("Keyword Suite 需要显式选择 Reference 语料、命名参考集或导入词表。", "Keyword Suite requires an explicit Reference corpus, named reference set, or imported word list.", mode: .system))
            return
        }

        let focusIDs = Set(focusCorpora.map(\.id))
        let referenceIDs = Set(referenceCorpora.map(\.id))
        if importedReferenceItems.isEmpty,
           focusIDs == referenceIDs,
           focusIDs.count == focusCorpora.count,
           referenceIDs.count == referenceCorpora.count {
            features.sidebar.setError(wordZText("Focus 与 Reference 不能完全相同。", "Focus and Reference cannot be identical.", mode: .system))
            return
        }

        await performResultRunTask(
            .keyword,
            selecting: .keyword,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) {
            let focusEntries = try await self.buildKeywordRequestEntries(from: focusCorpora)
            let referenceEntries = try await self.buildKeywordRequestEntries(from: referenceCorpora)
            let request = KeywordSuiteRunRequest(
                focusEntries: focusEntries,
                referenceEntries: referenceEntries,
                importedReferenceItems: importedReferenceItems,
                focusLabel: features.keyword.focusSelectionSummary,
                referenceLabel: features.keyword.referenceSelectionSummary,
                configuration: features.keyword.suiteConfiguration
            )
            features.keyword.recordPendingRunConfiguration()
            let result = try await self.repository.runKeywordSuite(request)
            features.keyword.apply(result)
        }
    }

    func runChiSquare(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        do {
            let inputs = try features.chiSquare.validatedInputs()
            await performResultRunTask(
                .chiSquare,
                selecting: .chiSquare,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            ) {
                let result = try await self.repository.runChiSquare(
                    a: inputs.0,
                    b: inputs.1,
                    c: inputs.2,
                    d: inputs.3,
                    yates: features.chiSquare.useYates
                )
                features.chiSquare.apply(result)
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runTopics(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        guard !isRunningTopicsAnalysis else { return }
        isRunningTopicsAnalysis = true
        var taskID: UUID?
        defer { isRunningTopicsAnalysis = false }

        do {
            let corpus = try await ensureOpenedCorpus(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let options = TopicAnalysisOptions(
                granularity: .paragraph,
                language: "english",
                minTopicSize: features.topics.minTopicSizeValue,
                includeOutliers: features.topics.includeOutliers,
                searchQuery: features.topics.normalizedQuery,
                searchOptions: features.topics.searchOptions,
                stopwordFilter: features.topics.stopwordFilter
            )
            let createdTaskID = taskCenter.beginTask(
                title: wordZText("Topics 建模", "Run Topics", mode: .system),
                detail: wordZText("正在准备主题建模…", "Preparing topic modeling…", mode: .system),
                progress: 0
            )
            taskID = createdTaskID

            let analysisTask = Task { () throws -> TopicAnalysisResult in
                if let progressRepository = repository as? TopicProgressReportingRepository {
                    return try await progressRepository.runTopics(text: corpus.content, options: options) { [weak taskCenter] progress in
                        Task { @MainActor in
                            taskCenter?.updateTask(
                                id: createdTaskID,
                                detail: self.localizedTopicProgressDetail(progress),
                                progress: progress.progress
                            )
                        }
                    }
                }
                return try await repository.runTopics(text: corpus.content, options: options)
            }
            taskCenter.registerCancelHandler(id: createdTaskID) {
                analysisTask.cancel()
            }

            let result = try await analysisTask.value
            features.topics.apply(result)
            completeRun(
                selecting: .topics,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            features.sidebar.clearError()
            taskCenter.completeTask(
                id: createdTaskID,
                detail: wordZText("Topics 结果已准备完成。", "Topics results are ready.", mode: .system)
            )
        } catch is CancellationError {
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
            if let taskID {
                taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            }
        }
    }

    func runSentiment(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        switch features.sentiment.source {
        case .openedCorpus:
            await performOpenedCorpusRunTask(
                .sentiment,
                selecting: .sentiment,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            ) { corpus in
                let text = SentimentInputText(
                    id: features.sidebar.selectedCorpusID ?? UUID().uuidString,
                    sourceID: features.sidebar.selectedCorpusID,
                    sourceTitle: corpus.displayName.isEmpty ? wordZText("当前语料", "Opened Corpus", mode: .system) : corpus.displayName,
                    text: corpus.content,
                    groupID: "target",
                    groupTitle: wordZText("目标语料", "Target", mode: .system)
                )
                let request = features.sentiment.currentRunRequest(texts: [text])
                let result = try await self.repository.runSentiment(request)
                features.sentiment.apply(result)
            }
        case .pastedText:
            let trimmed = features.sentiment.manualText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                features.sidebar.setError(wordZText("请先输入要分析的英文文本。", "Enter some English text to analyze first.", mode: .system))
                return
            }
            await performResultRunTask(
                .sentiment,
                selecting: .sentiment,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            ) {
                let text = SentimentInputText(
                    id: "manual-text",
                    sourceTitle: wordZText("粘贴文本", "Pasted Text", mode: .system),
                    text: trimmed,
                    groupID: "manual",
                    groupTitle: wordZText("手动输入", "Manual Input", mode: .system)
                )
                let request = features.sentiment.currentRunRequest(texts: [text])
                let result = try await self.repository.runSentiment(request)
                features.sentiment.apply(result)
            }
        case .kwicVisible:
            guard let scene = features.kwic.scene, !scene.rows.isEmpty else {
                features.sidebar.setError(wordZText("请先生成 KWIC 结果。", "Run KWIC first to analyze visible concordance lines.", mode: .system))
                return
            }
            let documentText = sessionStore.openedCorpus?.content
            await performResultRunTask(
                .sentiment,
                selecting: .sentiment,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            ) {
                let texts = scene.rows.map { row in
                    SentimentInputText(
                        id: row.id,
                        sourceID: features.sidebar.selectedCorpusID,
                        sourceTitle: wordZText("KWIC", "KWIC", mode: .system),
                        text: row.concordanceText,
                        sentenceID: row.sentenceId,
                        tokenIndex: row.sentenceTokenIndex,
                        groupID: "kwic",
                        groupTitle: wordZText("索引行", "Concordance", mode: .system),
                        documentText: documentText
                    )
                }
                let request = features.sentiment.currentRunRequest(texts: texts)
                let result = try await self.repository.runSentiment(request)
                features.sentiment.apply(result)
            }
        case .corpusCompare:
            let targetCorpora = features.sentiment.selectedTargetCorpusItems()
            guard !targetCorpora.isEmpty else {
                features.sidebar.setError(wordZText("请至少选择一条目标语料。", "Select at least one target corpus first.", mode: .system))
                return
            }

            await performResultRunTask(
                .sentiment,
                selecting: .sentiment,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            ) {
                var texts: [SentimentInputText] = []
                for corpus in targetCorpora {
                    let opened = try await self.repository.openSavedCorpus(corpusId: corpus.id)
                    texts.append(
                        SentimentInputText(
                            id: "target::\(corpus.id)",
                            sourceID: corpus.id,
                            sourceTitle: corpus.name,
                            text: opened.content,
                            groupID: "target",
                            groupTitle: wordZText("目标语料", "Target", mode: .system)
                        )
                    )
                }

                if let referenceCorpus = features.sentiment.selectedReferenceCorpusItem() {
                    let opened = try await self.repository.openSavedCorpus(corpusId: referenceCorpus.id)
                    texts.append(
                        SentimentInputText(
                            id: "reference::\(referenceCorpus.id)",
                            sourceID: referenceCorpus.id,
                            sourceTitle: referenceCorpus.name,
                            text: opened.content,
                            groupID: "reference",
                            groupTitle: wordZText("参照语料", "Reference", mode: .system)
                        )
                    )
                }

                let request = features.sentiment.currentRunRequest(texts: texts)
                let result = try await self.repository.runSentiment(request)
                features.sentiment.apply(result)
            }
        }
    }

    func runPlot(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let normalizedQuery = features.plot.normalizedQuery
        guard !normalizedQuery.isEmpty else {
            features.sidebar.setError(wordZText("请输入 Plot 检索词。", "Enter a Plot query first.", mode: .system))
            return
        }

        await performResultRunTask(
            .plot,
            selecting: .plot,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) {
            let scope = self.resolvedPlotScope(features: features)
            let entries = try await self.buildPlotEntries(
                scope: scope,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            let request = features.plot.currentRunRequest(entries: entries, scope: scope)
            let result = try await self.repository.runPlot(request)
            features.plot.apply(result)
        }
    }

    func preparePlotKWIC(
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        guard !features.plot.normalizedQuery.isEmpty else {
            features.sidebar.setError(wordZText("请输入 Plot 检索词。", "Enter a Plot query first.", mode: .system))
            return false
        }
        guard let row = features.plot.selectedSceneRow else {
            features.sidebar.setError(wordZText("请先选择一条 Plot 结果。", "Select a Plot row first.", mode: .system))
            return false
        }
        guard features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == row.corpusId }) else {
            features.sidebar.setError(wordZText("当前 Plot 结果没有可用的语料上下文。", "The current Plot row has no usable corpus context.", mode: .system))
            return false
        }

        do {
            try await prepareDrilldownCorpusSelection(
                row.corpusId,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        features.kwic.keyword = features.plot.normalizedQuery
        features.kwic.searchOptions = features.plot.searchOptions
        if let marker = features.plot.selectedSceneMarker {
            features.kwic.selectedRowID = "\(marker.sentenceId)-\(marker.tokenIndex)"
        } else {
            features.kwic.selectedRowID = nil
        }
        features.shell.selectedTab = .kwic
        markWorkspaceEdited(features)
        return true
    }

    func runCluster(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        await performOpenedCorpusRunTask(
            .cluster,
            selecting: .cluster,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) { corpus in
            let targetEntry = ClusterCorpusEntry(
                corpusId: features.sidebar.selectedCorpusID ?? corpus.filePath,
                corpusName: corpus.displayName,
                content: corpus.content
            )
            let referenceEntries: [ClusterCorpusEntry]
            let trimmedReferenceCorpusID = features.cluster.referenceCorpusID
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if features.cluster.mode == .targetReference,
               !trimmedReferenceCorpusID.isEmpty,
               trimmedReferenceCorpusID != targetEntry.corpusId {
                let openedReference = try await self.repository.openSavedCorpus(corpusId: trimmedReferenceCorpusID)
                let referenceName = features.sidebar.librarySnapshot.corpora.first(where: { $0.id == trimmedReferenceCorpusID })?.name
                    ?? openedReference.displayName
                referenceEntries = [
                    ClusterCorpusEntry(
                        corpusId: trimmedReferenceCorpusID,
                        corpusName: referenceName,
                        content: openedReference.content
                    )
                ]
            } else {
                referenceEntries = []
            }

            let request = ClusterRunRequest(
                targetEntries: [targetEntry],
                referenceEntries: referenceEntries,
                caseSensitive: features.cluster.caseSensitive,
                stopwordFilter: features.cluster.stopwordFilter,
                punctuationMode: features.cluster.punctuationMode,
                nValues: [2, 3, 4, 5]
            )
            let result = try await self.repository.runCluster(request)
            features.cluster.apply(result)
        }
    }

    func prepareClusterKWIC(
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        guard let row = features.cluster.selectedSceneRow else {
            features.sidebar.setError(wordZText("请先选择一条 Cluster 结果。", "Select a cluster row first.", mode: .system))
            return false
        }
        guard let corpusID = features.sidebar.selectedCorpusID,
              features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == corpusID }) else {
            features.sidebar.setError(wordZText("当前 Cluster 结果没有可用的语料范围。", "The current cluster result has no usable corpus context.", mode: .system))
            return false
        }

        do {
            try await prepareDrilldownCorpusSelection(
                corpusID,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        features.kwic.keyword = row.phrase
        features.kwic.searchOptions = SearchOptionsState(
            words: true,
            caseSensitive: features.cluster.caseSensitive,
            regex: false,
            matchMode: .phraseExact
        )
        if features.kwic.leftWindow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.kwic.leftWindow = "5"
        }
        if features.kwic.rightWindow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.kwic.rightWindow = "5"
        }
        features.shell.selectedTab = .kwic
        markWorkspaceEdited(features)
        return true
    }

    func prepareCompareDrilldown(
        target: CompareDrilldownTarget,
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        guard let row = selectedCompareResultRow(features: features) else {
            features.sidebar.setError("请先选择一条 Compare 结果。")
            return false
        }
        guard let resolvedCorpus = resolveCompareDrilldownCorpus(for: row, features: features),
              features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == resolvedCorpus.corpusId }) else {
            features.sidebar.setError("当前 Compare 结果没有可用的语料上下文。")
            return false
        }

        do {
            try await prepareDrilldownCorpusSelection(
                resolvedCorpus.corpusId,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        switch target {
        case .kwic:
            features.kwic.keyword = row.word
            features.shell.selectedTab = .kwic
        case .collocate:
            features.collocate.keyword = row.word
            features.shell.selectedTab = .collocate
        }
        markWorkspaceEdited(features)
        return true
    }

    func prepareCollocateKWIC(
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        guard let row = features.collocate.selectedSceneRow else {
            features.sidebar.setError("请先选择一条搭配词结果。")
            return false
        }
        let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID,
              features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == corpusID }) else {
            features.sidebar.setError("当前搭配词结果没有可用的语料范围。")
            return false
        }

        do {
            try await prepareDrilldownCorpusSelection(
                corpusID,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        features.kwic.keyword = row.word
        features.shell.selectedTab = .kwic
        markWorkspaceEdited(features)
        return true
    }

    private func buildKeywordRequestEntries(
        from corpora: [LibraryCorpusItem]
    ) async throws -> [KeywordRequestEntry] {
        var entries: [KeywordRequestEntry] = []
        for corpus in corpora {
            let opened = try await repository.openSavedCorpus(corpusId: corpus.id)
            entries.append(
                KeywordRequestEntry(
                    corpusId: corpus.id,
                    corpusName: corpus.name,
                    folderName: corpus.folderName,
                    content: opened.content
                )
            )
        }
        return entries
    }

    private func resolvedPlotScope(features: WorkspaceFeatureSet) -> PlotScopeResolution {
        if features.sidebar.selectedCorpusSetID != nil || features.sidebar.hasAnyMetadataFilterInput {
            return .corpusRange
        }
        return .singleCorpus
    }

    private func buildPlotEntries(
        scope: PlotScopeResolution,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws -> [PlotCorpusEntry] {
        switch scope {
        case .singleCorpus:
            let openedCorpus = try await ensureOpenedCorpus(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            let selectedCorpus = features.sidebar.selectedCorpus
            let corpusID = features.sidebar.selectedCorpusID
                ?? sessionStore.openedCorpusSourceID
                ?? selectedCorpus?.id
                ?? UUID().uuidString
            return [
                PlotCorpusEntry(
                    corpusId: corpusID,
                    displayName: selectedCorpus?.name ?? openedCorpus.displayName,
                    filePath: openedCorpus.filePath,
                    content: openedCorpus.content
                )
            ]
        case .corpusRange:
            var entries: [PlotCorpusEntry] = []
            for corpus in features.sidebar.filteredCorpora {
                let openedCorpus = try await repository.openSavedCorpus(corpusId: corpus.id)
                entries.append(
                    PlotCorpusEntry(
                        corpusId: corpus.id,
                        displayName: corpus.name,
                        filePath: openedCorpus.filePath,
                        content: openedCorpus.content
                    )
                )
            }
            return entries
        }
    }

    func prepareDrilldownCorpusSelection(
        _ corpusID: String,
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws {
        features.sidebar.setSelectedCorpusID(corpusID, notifySelectionChange: false)
        features.library.selectCorpus(corpusID)
        prepareCorpusSelectionChange(features)
        _ = try await ensureOpenedCorpus(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        features.sidebar.clearError()
    }

    private func selectedCompareResultRow(features: WorkspaceFeatureSet) -> CompareRow? {
        guard let result = features.compare.result else { return nil }
        let rowID = features.compare.selectedSceneRow?.id ?? features.compare.selectedRowID
        guard let rowID else { return result.rows.first }
        return result.rows.first(where: { $0.id == rowID }) ?? result.rows.first
    }

    private func resolveCompareDrilldownCorpus(
        for row: CompareRow,
        features: WorkspaceFeatureSet
    ) -> ComparePerCorpusValue? {
        let referenceCorpusIDs = compareReferenceCorpusIDs(features: features)
        guard !referenceCorpusIDs.isEmpty else {
            return preferredCompareCorpus(from: row.perCorpus)
        }

        let referenceEntries = row.perCorpus.filter { referenceCorpusIDs.contains($0.corpusId) }
        let targetEntries = row.perCorpus.filter { !referenceCorpusIDs.contains($0.corpusId) }
        guard !referenceEntries.isEmpty, !targetEntries.isEmpty else {
            return preferredCompareCorpus(from: row.perCorpus)
        }

        let preferredEntries = compareGroupNormFrequency(for: targetEntries) >= compareGroupNormFrequency(for: referenceEntries)
            ? targetEntries
            : referenceEntries
        return preferredCompareCorpus(from: preferredEntries) ?? preferredCompareCorpus(from: row.perCorpus)
    }

    private func compareReferenceCorpusIDs(features: WorkspaceFeatureSet) -> Set<String> {
        switch features.compare.selectedReferenceSelection {
        case .automatic:
            return []
        case .corpus(let corpusID):
            return [corpusID]
        case .corpusSet:
            return Set(features.compare.selectedReferenceCorpusSet()?.corpusIDs ?? [])
        }
    }

    private func compareGroupNormFrequency(for entries: [ComparePerCorpusValue]) -> Double {
        let tokenCount = entries.reduce(0) { $0 + $1.tokenCount }
        guard tokenCount > 0 else { return 0 }
        let totalCount = entries.reduce(0) { $0 + $1.count }
        return (Double(totalCount) / Double(tokenCount)) * 10_000
    }

    private func preferredCompareCorpus(from entries: [ComparePerCorpusValue]) -> ComparePerCorpusValue? {
        entries.max { lhs, rhs in
            if lhs.normFreq != rhs.normFreq {
                return lhs.normFreq < rhs.normFreq
            }
            if lhs.count != rhs.count {
                return lhs.count < rhs.count
            }
            return lhs.corpusId > rhs.corpusId
        }
    }
}
