import AppKit
import Foundation

@MainActor
final class WorkspaceFlowCoordinator {
    struct WorkspaceRunTaskDescriptor {
        let titleZh: String
        let titleEn: String
        let detailZh: String
        let detailEn: String
        let successZh: String
        let successEn: String

        func title(in mode: AppLanguageMode) -> String {
            wordZText(titleZh, titleEn, mode: mode)
        }

        func detail(in mode: AppLanguageMode) -> String {
            wordZText(detailZh, detailEn, mode: mode)
        }

        func success(in mode: AppLanguageMode) -> String {
            wordZText(successZh, successEn, mode: mode)
        }

        static let stats = Self(
            titleZh: "统计分析",
            titleEn: "Run Stats",
            detailZh: "正在统计词频与基础指标…",
            detailEn: "Calculating frequencies and core metrics…",
            successZh: "统计结果已生成。",
            successEn: "Stats results are ready."
        )
        static let word = Self(
            titleZh: "词表分析",
            titleEn: "Run Word List",
            detailZh: "正在整理词项与频次…",
            detailEn: "Preparing lexical items and counts…",
            successZh: "词表结果已生成。",
            successEn: "Word list results are ready."
        )
        static let tokenize = Self(
            titleZh: "分词分析",
            titleEn: "Run Tokenize",
            detailZh: "正在切分文本并生成词元…",
            detailEn: "Tokenizing the corpus text…",
            successZh: "分词结果已生成。",
            successEn: "Tokenization results are ready."
        )
        static let compare = Self(
            titleZh: "多语料对比",
            titleEn: "Run Compare",
            detailZh: "正在汇总多语料频次差异…",
            detailEn: "Comparing frequencies across corpora…",
            successZh: "对比结果已生成。",
            successEn: "Comparison results are ready."
        )
        static let chiSquare = Self(
            titleZh: "卡方检验",
            titleEn: "Run Chi-Square",
            detailZh: "正在计算列联表统计量…",
            detailEn: "Calculating contingency table statistics…",
            successZh: "卡方结果已生成。",
            successEn: "Chi-square results are ready."
        )
        static let kwic = Self(
            titleZh: "KWIC 索引行",
            titleEn: "Run KWIC",
            detailZh: "正在定位节点词上下文…",
            detailEn: "Locating keyword-in-context rows…",
            successZh: "KWIC 结果已生成。",
            successEn: "KWIC results are ready."
        )
        static let ngram = Self(
            titleZh: "N-Gram 分析",
            titleEn: "Run N-Gram",
            detailZh: "正在统计连续词串…",
            detailEn: "Counting contiguous token sequences…",
            successZh: "N-Gram 结果已生成。",
            successEn: "N-gram results are ready."
        )
        static let wordCloud = Self(
            titleZh: "词云分析",
            titleEn: "Run Word Cloud",
            detailZh: "正在整理高频词分布…",
            detailEn: "Preparing the high-frequency term cloud…",
            successZh: "词云结果已生成。",
            successEn: "Word cloud results are ready."
        )
        static let collocate = Self(
            titleZh: "搭配分析",
            titleEn: "Run Collocate",
            detailZh: "正在计算搭配词与窗口统计…",
            detailEn: "Calculating collocates and window statistics…",
            successZh: "搭配结果已生成。",
            successEn: "Collocate results are ready."
        )
        static let locator = Self(
            titleZh: "句子定位",
            titleEn: "Run Locator",
            detailZh: "正在定位索引行所在上下文…",
            detailEn: "Locating the surrounding sentence context…",
            successZh: "定位结果已生成。",
            successEn: "Locator results are ready."
        )
    }

    private let repository: any WorkspaceRepository
    private let workspacePersistence: WorkspacePersistenceService
    private let workspacePresentation: WorkspacePresentationService
    private let sceneStore: WorkspaceSceneStore
    private let windowDocumentController: NativeWindowDocumentController
    private let dialogService: NativeDialogServicing
    private let hostActionService: any NativeHostActionServicing
    private let sessionStore: WorkspaceSessionStore
    private let hostPreferencesStore: any NativeHostPreferencesStoring
    private let libraryCoordinator: LibraryCoordinator
    private let libraryManagementCoordinator: LibraryManagementCoordinator
    private let exportCoordinator: WorkspaceExportCoordinator
    private let taskCenter: NativeTaskCenter
    private var isRunningTopicsAnalysis = false

    init(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: NativeWindowDocumentController,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing = NativeHostActionService(dialogService: NativeSheetDialogService()),
        sessionStore: WorkspaceSessionStore,
        hostPreferencesStore: any NativeHostPreferencesStoring = NativeHostPreferencesStore(),
        libraryCoordinator: LibraryCoordinator,
        taskCenter: NativeTaskCenter = NativeTaskCenter()
    ) {
        self.repository = repository
        self.workspacePersistence = workspacePersistence
        self.workspacePresentation = workspacePresentation
        self.sceneStore = sceneStore
        self.windowDocumentController = windowDocumentController
        self.dialogService = dialogService
        self.hostActionService = hostActionService
        self.sessionStore = sessionStore
        self.hostPreferencesStore = hostPreferencesStore
        self.libraryCoordinator = libraryCoordinator
        self.taskCenter = taskCenter
        self.libraryManagementCoordinator = LibraryManagementCoordinator(
            repository: repository,
            dialogService: dialogService,
            sessionStore: sessionStore
        )
        self.exportCoordinator = WorkspaceExportCoordinator(dialogService: dialogService)
    }

    func attachWindow(_ window: NSWindow?, features: WorkspaceFeatureSet) {
        windowDocumentController.attach(window: window)
        dialogService.attach(window: window)
        libraryManagementCoordinator.attach(window: window)
        exportCoordinator.attach(window: window)
        syncWindowDocumentState(features: features)
    }

    func openSelectedCorpus(features: WorkspaceFeatureSet) async {
        setBusy(true, features: features)
        defer { setBusy(false, features: features) }

        do {
            _ = try await libraryCoordinator.openSelection(selectedCorpusID: features.sidebar.selectedCorpusID)
            applyWorkspacePresentation(features: features)
            refreshRecentDocuments(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
            syncWindowDocumentState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runStats(features: WorkspaceFeatureSet) async {
        await performWorkspaceRunTask(.stats, features: features) {
            let corpus = try await self.ensureOpenedCorpus(features: features)
            let result = try await self.repository.runStats(text: corpus.content)
            features.stats.apply(result)
            features.word.apply(result)
            features.shell.selectedTab = .stats
            self.applyWorkspacePresentation(features: features)
            self.persistWorkspaceState(features: features)
        }
    }

    func runWord(features: WorkspaceFeatureSet) async {
        await performWorkspaceRunTask(.word, features: features) {
            let corpus = try await self.ensureOpenedCorpus(features: features)
            let result = try await self.repository.runStats(text: corpus.content)
            features.stats.apply(result)
            features.word.apply(result)
            features.shell.selectedTab = .word
            self.applyWorkspacePresentation(features: features)
            self.persistWorkspaceState(features: features)
        }
    }

    func runTokenize(features: WorkspaceFeatureSet) async {
        await performWorkspaceRunTask(.tokenize, features: features) {
            let corpus = try await self.ensureOpenedCorpus(features: features)
            let result = try await self.repository.runTokenize(text: corpus.content)
            features.tokenize.apply(result)
            features.shell.selectedTab = .tokenize
            self.applyWorkspacePresentation(features: features)
            self.persistWorkspaceState(features: features)
        }
    }

    func runTopics(features: WorkspaceFeatureSet) async {
        guard !isRunningTopicsAnalysis else { return }
        isRunningTopicsAnalysis = true
        var taskID: UUID?
        defer { isRunningTopicsAnalysis = false }
        do {
            let corpus = try await ensureOpenedCorpus(features: features)
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
            features.shell.selectedTab = .topics
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
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

    func runCompare(features: WorkspaceFeatureSet) async {
        let selectedCorpora = features.compare.selectedCorpusItems()
        guard selectedCorpora.count >= 2 else {
            features.sidebar.setError("Compare 至少需要选择 2 条语料。")
            return
        }

        await performWorkspaceRunTask(.compare, features: features) {
            let comparisonEntries = try await self.buildComparisonEntries(from: selectedCorpora)
            let result = try await self.repository.runCompare(comparisonEntries: comparisonEntries)
            features.compare.apply(result)
            features.shell.selectedTab = .compare
            self.applyWorkspacePresentation(features: features)
            self.persistWorkspaceState(features: features)
        }
    }

    func runChiSquare(features: WorkspaceFeatureSet) async {
        do {
            let inputs = try features.chiSquare.validatedInputs()
            await performWorkspaceRunTask(.chiSquare, features: features) {
                let result = try await self.repository.runChiSquare(
                    a: inputs.0,
                    b: inputs.1,
                    c: inputs.2,
                    d: inputs.3,
                    yates: features.chiSquare.useYates
                )
                features.chiSquare.apply(result)
                features.shell.selectedTab = .chiSquare
                self.applyWorkspacePresentation(features: features)
                self.persistWorkspaceState(features: features)
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runKWIC(features: WorkspaceFeatureSet) async {
        let keyword = features.kwic.normalizedKeyword
        guard !keyword.isEmpty else {
            features.sidebar.setError("请输入 KWIC 关键词。")
            return
        }

        await performWorkspaceRunTask(.kwic, features: features) {
            let corpus = try await self.ensureOpenedCorpus(features: features)
            let result = try await self.repository.runKWIC(
                text: corpus.content,
                keyword: keyword,
                leftWindow: features.kwic.leftWindowValue,
                rightWindow: features.kwic.rightWindowValue,
                searchOptions: features.kwic.searchOptions
            )
            features.kwic.apply(result)
            features.shell.selectedTab = .kwic
            self.applyWorkspacePresentation(features: features)
            self.persistWorkspaceState(features: features)
        }
    }

    func runNgram(features: WorkspaceFeatureSet) async {
        await performWorkspaceRunTask(.ngram, features: features) {
            let corpus = try await self.ensureOpenedCorpus(features: features)
            let result = try await self.repository.runNgram(
                text: corpus.content,
                n: features.ngram.ngramSizeValue
            )
            features.ngram.apply(result)
            features.shell.selectedTab = .ngram
            self.applyWorkspacePresentation(features: features)
            self.persistWorkspaceState(features: features)
        }
    }

    func runWordCloud(features: WorkspaceFeatureSet) async {
        await performWorkspaceRunTask(.wordCloud, features: features) {
            let corpus = try await self.ensureOpenedCorpus(features: features)
            let result = try await self.repository.runWordCloud(text: corpus.content, limit: features.wordCloud.limit)
            features.wordCloud.apply(result)
            features.shell.selectedTab = .wordCloud
            self.applyWorkspacePresentation(features: features)
            self.persistWorkspaceState(features: features)
        }
    }

    func runCollocate(features: WorkspaceFeatureSet) async {
        let keyword = features.collocate.normalizedKeyword
        guard !keyword.isEmpty else {
            features.sidebar.setError("请输入 Collocate 节点词。")
            return
        }

        await performWorkspaceRunTask(.collocate, features: features) {
            let corpus = try await self.ensureOpenedCorpus(features: features)
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
            features.shell.selectedTab = .collocate
            self.applyWorkspacePresentation(features: features)
            self.persistWorkspaceState(features: features)
        }
    }

    func runLocator(features: WorkspaceFeatureSet) async {
        guard let source = features.locator.currentSource ?? features.kwic.primaryLocatorSource else {
            features.sidebar.setError("请先运行 KWIC，Locator 会默认定位第一条结果。")
            return
        }

        await performWorkspaceRunTask(.locator, features: features) {
            let corpus = try await self.ensureOpenedCorpus(features: features)
            let result = try await self.repository.runLocator(
                text: corpus.content,
                sentenceId: source.sentenceId,
                nodeIndex: source.nodeIndex,
                leftWindow: features.locator.leftWindowValue,
                rightWindow: features.locator.rightWindowValue
            )
            features.locator.apply(result, source: source)
            features.shell.selectedTab = .locator
            self.applyWorkspacePresentation(features: features)
            self.persistWorkspaceState(features: features)
        }
    }

    func saveSettings(features: WorkspaceFeatureSet) async {
        do {
            try await repository.saveUISettings(features.settings.exportSnapshot())
            try hostPreferencesStore.save(features.settings.exportHostPreferences())
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func refreshLibraryManagement(features: WorkspaceFeatureSet) async {
        do {
            features.library.setBusy(true)
            defer { features.library.setBusy(false) }
            try await libraryManagementCoordinator.refreshLibraryState(
                into: features.library,
                sidebar: features.sidebar
            )
            features.sidebar.clearError()
        } catch {
            features.library.setError(error.localizedDescription)
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func handleLibraryAction(_ action: LibraryManagementAction, features: WorkspaceFeatureSet) async {
        do {
            let shouldTrackBusy: Bool
            switch action {
            case .selectFolder, .selectCorpus, .selectRecycleEntry, .openSelectedCorpus, .quickLookSelectedCorpus, .editSelectedCorpusMetadata:
                shouldTrackBusy = false
            default:
                shouldTrackBusy = true
            }
            if shouldTrackBusy {
                features.library.setBusy(true)
            }
            defer {
                if shouldTrackBusy {
                    features.library.setBusy(false)
                }
            }
            switch action {
            case .selectFolder, .selectCorpus, .selectRecycleEntry, .openSelectedCorpus, .quickLookSelectedCorpus, .editSelectedCorpusMetadata:
                break
            case .refresh:
                try await libraryManagementCoordinator.refreshLibraryState(into: features.library, sidebar: features.sidebar)
            case .importPaths:
                _ = try await libraryManagementCoordinator.importPaths(into: features.library, sidebar: features.sidebar)
            case .createFolder:
                try await libraryManagementCoordinator.createFolder(into: features.library, sidebar: features.sidebar)
            case .renameSelectedCorpus:
                try await libraryManagementCoordinator.renameSelectedCorpus(into: features.library, sidebar: features.sidebar)
            case .moveSelectedCorpusToSelectedFolder:
                try await libraryManagementCoordinator.moveSelectedCorpusToFolder(into: features.library, sidebar: features.sidebar)
            case .deleteSelectedCorpus:
                try await libraryManagementCoordinator.deleteSelectedCorpus(into: features.library, sidebar: features.sidebar)
            case .showSelectedCorpusInfo:
                try await showSelectedCorpusInfo(features: features)
            case .saveSelectedCorpusMetadata(let metadata):
                try await libraryManagementCoordinator.updateSelectedCorpusMetadata(metadata, into: features.library, sidebar: features.sidebar)
            case .renameSelectedFolder:
                try await libraryManagementCoordinator.renameSelectedFolder(into: features.library, sidebar: features.sidebar)
            case .deleteSelectedFolder:
                try await libraryManagementCoordinator.deleteSelectedFolder(into: features.library, sidebar: features.sidebar)
            case .backupLibrary:
                try await libraryManagementCoordinator.backupLibrary(into: features.library, sidebar: features.sidebar)
            case .restoreLibrary:
                try await libraryManagementCoordinator.restoreLibrary(into: features.library, sidebar: features.sidebar)
            case .repairLibrary:
                try await libraryManagementCoordinator.repairLibrary(into: features.library, sidebar: features.sidebar)
            case .restoreSelectedRecycleEntry:
                try await libraryManagementCoordinator.restoreSelectedRecycleEntry(into: features.library, sidebar: features.sidebar)
            case .purgeSelectedRecycleEntry:
                try await libraryManagementCoordinator.purgeSelectedRecycleEntry(into: features.library, sidebar: features.sidebar)
            }
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
        } catch {
            features.library.setError(error.localizedDescription)
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func showSelectedCorpusInfo(features: WorkspaceFeatureSet) async throws {
        guard let selectedCorpus = features.library.selectedCorpus ?? features.sidebar.selectedCorpus else {
            return
        }
        let summary = try await repository.loadCorpusInfo(corpusId: selectedCorpus.id)
        features.library.presentCorpusInfo(
            LibraryCorpusInfoSceneModel(
                id: summary.corpusId,
                title: summary.title,
                subtitle: wordZText("语料信息", "Corpus Info", mode: .system),
                folderName: summary.folderName,
                sourceType: summary.sourceType,
                sourceLabelText: summary.metadata.sourceLabel.isEmpty ? "—" : summary.metadata.sourceLabel,
                yearText: summary.metadata.yearLabel.isEmpty ? "—" : summary.metadata.yearLabel,
                genreText: summary.metadata.genreLabel.isEmpty ? "—" : summary.metadata.genreLabel,
                tagsText: summary.metadata.tagsText.isEmpty ? "—" : summary.metadata.tagsText,
                importedAtText: summary.importedAt.isEmpty ? "—" : summary.importedAt,
                encodingText: summary.detectedEncoding.isEmpty ? "—" : summary.detectedEncoding,
                tokenCountText: "\(summary.tokenCount)",
                typeCountText: "\(summary.typeCount)",
                sentenceCountText: "\(summary.sentenceCount)",
                paragraphCountText: "\(summary.paragraphCount)",
                characterCountText: "\(summary.characterCount)",
                ttrText: String(format: "%.4f", summary.ttr),
                sttrText: summary.sttr > 0 ? String(format: "%.4f", summary.sttr) : "—",
                representedPath: summary.representedPath
            )
        )
        features.library.setStatus(wordZText("已载入语料信息。", "Loaded corpus information.", mode: .system))
    }

    func exportCurrent(features: WorkspaceFeatureSet) async {
        do {
            let savedPath: String?
            if features.shell.selectedTab == .tokenize,
               let document = features.tokenize.exportDocument {
                savedPath = try await exportCoordinator.export(
                    textDocument: document,
                    title: wordZText("导出分词结果", "Export Tokenized Text", mode: .system)
                )
            } else {
                let graph = buildSceneGraph(features: features)
                savedPath = try await exportCoordinator.exportActiveScene(graph: graph)
            }
            if let savedPath {
                features.library.setStatus("已导出到 \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportTextDocument(
        _ document: PlainTextExportDocument,
        title: String,
        successStatus: String,
        features: WorkspaceFeatureSet
    ) async {
        do {
            if let savedPath = try await exportCoordinator.export(textDocument: document, title: title) {
                features.library.setStatus("\(successStatus) \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportSnapshot(
        _ snapshot: NativeTableExportSnapshot,
        title: String,
        successStatus: String,
        features: WorkspaceFeatureSet
    ) async {
        do {
            if let savedPath = try await exportCoordinator.export(snapshot: snapshot, title: title) {
                features.library.setStatus("\(successStatus) \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func importCorpusFromDialog(features: WorkspaceFeatureSet) async {
        do {
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }
            guard let result = try await libraryManagementCoordinator.importPaths(
                into: features.library,
                sidebar: features.sidebar
            ) else {
                return
            }
            try await handleImportedCorpora(result, features: features)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
            features.library.setError(error.localizedDescription)
        }
    }

    func importExternalPaths(_ paths: [String], features: WorkspaceFeatureSet) async {
        guard !paths.isEmpty else { return }
        do {
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }
            let targetFolderID = features.library.selectedFolderID ?? ""
            let result = try await repository.importCorpusPaths(paths, folderId: targetFolderID, preserveHierarchy: false)
            try await libraryManagementCoordinator.refreshLibraryState(into: features.library, sidebar: features.sidebar)
            try await handleImportedCorpora(result, features: features)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
            features.library.setError(error.localizedDescription)
        }
    }

    func restoreSelectionFromWorkspace(
        features: WorkspaceFeatureSet,
        restoreWorkspace: Bool
    ) {
        sessionStore.beginRestore()
        defer {
            sessionStore.finishRestore()
            features.shell.updateSelectionAvailability(
                hasSelection: features.sidebar.selectedCorpusID != nil,
                hasPreviewableCorpus: !(features.library.selectedCorpus?.representedPath.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty,
                corpusCount: features.sidebar.librarySnapshot.corpora.count,
                hasLocatorSource: features.kwic.primaryLocatorSource != nil,
                hasExportableContent: false
            )
            syncFeatureContexts(features: features)
        }

        if restoreWorkspace, let workspaceSnapshot = sessionStore.workspaceSnapshot {
            applyWorkspaceSnapshot(workspaceSnapshot, features: features)
            return
        }

        if let currentSelection = features.sidebar.selectedCorpusID,
           features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == currentSelection }) {
            return
        }

        let preferredName = sessionStore.workspaceSnapshot?.corpusNames.first
        if let preferredName,
           let matchingCorpus = features.sidebar.librarySnapshot.corpora.first(where: { $0.name == preferredName }) {
            features.sidebar.selectedCorpusID = matchingCorpus.id
            return
        }

        features.sidebar.selectedCorpusID = features.sidebar.librarySnapshot.corpora.first?.id
    }

    func newWorkspace(features: WorkspaceFeatureSet) async {
        let emptyDraft = WorkspaceStateDraft.empty
        sessionStore.beginRestore()
        defer {
            sessionStore.finishRestore()
            applyWorkspacePresentation(features: features)
            syncWindowDocumentState(features: features)
        }

        resetFeatureResults(features: features)
        sessionStore.resetToEmptyWorkspace()
        features.stats.apply(.empty)
        features.word.apply(.empty)
        features.shell.selectedTab = .stats
        features.sidebar.selectedCorpusID = nil
        features.library.selectCorpus(nil)
        features.library.selectRecycleEntry(nil)
        features.library.selectFolder(nil)
        features.sidebar.clearError()
        features.library.setStatus(wordZText("已创建空白工作区。", "Created a new workspace.", mode: .system))

        do {
            try await repository.saveWorkspaceState(emptyDraft)
            sessionStore.applySavedDraft(emptyDraft)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func restoreSavedWorkspace(features: WorkspaceFeatureSet) async {
        guard let workspaceSnapshot = sessionStore.workspaceSnapshot else { return }
        sessionStore.beginRestore()
        defer {
            sessionStore.finishRestore()
            applyWorkspacePresentation(features: features)
            syncWindowDocumentState(features: features)
        }

        resetFeatureResults(features: features)
        applyWorkspaceSnapshot(workspaceSnapshot, features: features)
        features.sidebar.clearError()
        features.library.setStatus(wordZText("已恢复最近保存的工作区。", "Restored the last saved workspace.", mode: .system))
    }

    func handleCorpusSelectionChange(features: WorkspaceFeatureSet) {
        if libraryCoordinator.handleSelectionChange(to: features.sidebar.selectedCorpusID) {
            features.stats.reset()
            features.word.reset()
            features.tokenize.reset()
            features.topics.reset()
            features.compare.reset()
            features.chiSquare.reset()
            features.ngram.reset()
            features.wordCloud.reset()
            features.kwic.reset()
            features.collocate.reset()
            features.locator.reset()
        }
        markWorkspaceEdited(features: features)
    }

    func markWorkspaceEdited(features: WorkspaceFeatureSet) {
        guard !sessionStore.isRestoringState else { return }
        sessionStore.markEdited()
        applyWorkspacePresentation(features: features)
        persistWorkspaceState(features: features)
        syncWindowDocumentState(features: features)
    }

    func applyWorkspacePresentation(features: WorkspaceFeatureSet) {
        let presentation = workspacePresentation.buildPresentation(
            appInfo: sceneStore.appInfoSnapshot,
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            workspaceSnapshot: sessionStore.workspaceSnapshot
        )
        sceneStore.applyPresentation(presentation)
        syncFeatureContexts(features: features)
    }

    func syncWindowDocumentState(features: WorkspaceFeatureSet) {
        let presentation = workspacePresentation.buildPresentation(
            appInfo: sceneStore.appInfoSnapshot,
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            workspaceSnapshot: sessionStore.workspaceSnapshot
        )
        windowDocumentController.sync(
            displayName: presentation.displayName,
            representedPath: presentation.representedPath,
            edited: sessionStore.isDocumentEdited
        )
    }

    private func ensureOpenedCorpus(features: WorkspaceFeatureSet) async throws -> OpenedCorpus {
        let corpus = try await libraryCoordinator.ensureOpenedCorpus(
            selectedCorpusID: features.sidebar.selectedCorpusID
        )
        applyWorkspacePresentation(features: features)
        refreshRecentDocuments(features: features)
        syncWindowDocumentState(features: features)
        return corpus
    }

    private func persistWorkspaceState(features: WorkspaceFeatureSet) {
        guard !sessionStore.isRestoringState else { return }
        let draft = currentWorkspaceDraft(features: features)

        Task {
            do {
                try await repository.saveWorkspaceState(draft)
                await MainActor.run {
                    self.sessionStore.applySavedDraft(draft)
                    self.applyWorkspacePresentation(features: features)
                    self.syncWindowDocumentState(features: features)
                }
            } catch {
                await MainActor.run {
                    features.sidebar.setError(error.localizedDescription)
                }
            }
        }
    }

    func currentWorkspaceDraft(features: WorkspaceFeatureSet) -> WorkspaceStateDraft {
        let searchState = makeSearchPersistenceState(features: features)
        return workspacePersistence.buildDraft(
            selectedTab: features.shell.selectedTab,
            selectedFolderID: features.library.selectedFolderID ?? "all",
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            searchQuery: searchState.query,
            searchOptions: searchState.options,
            stopwordFilter: searchState.stopwordFilter,
            compareReferenceCorpusID: features.compare.selectedReferenceCorpusIDSnapshot,
            compareSelectedCorpusIDs: features.compare.selectedCorpusIDsSnapshot,
            ngramSize: features.ngram.ngramSize,
            ngramPageSize: features.ngram.pageSizeSnapshotValue,
            kwicLeftWindow: features.kwic.leftWindow,
            kwicRightWindow: features.kwic.rightWindow,
            collocateLeftWindow: features.collocate.leftWindow,
            collocateRightWindow: features.collocate.rightWindow,
            collocateMinFreq: features.collocate.minFreq,
            topicsMinTopicSize: features.topics.minTopicSize,
            topicsIncludeOutliers: features.topics.includeOutliers,
            topicsPageSize: sceneStoreTopicsPageSize(features),
            topicsActiveTopicID: features.topics.scene?.selectedClusterID ?? "",
            wordCloudLimit: features.wordCloud.limit,
            frequencyNormalizationUnit: features.stats.metricDefinition.normalizationUnit,
            frequencyRangeMode: features.stats.metricDefinition.rangeMode,
            chiSquareA: features.chiSquare.a,
            chiSquareB: features.chiSquare.b,
            chiSquareC: features.chiSquare.c,
            chiSquareD: features.chiSquare.d,
            chiSquareUseYates: features.chiSquare.useYates
        )
    }

    private func applyWorkspaceSnapshot(_ workspaceSnapshot: WorkspaceSnapshotSummary, features: WorkspaceFeatureSet) {
        features.stats.apply(workspaceSnapshot)
        features.word.apply(workspaceSnapshot)
        features.tokenize.apply(workspaceSnapshot)
        features.topics.apply(workspaceSnapshot)
        features.compare.apply(workspaceSnapshot)
        features.chiSquare.apply(workspaceSnapshot)
        features.wordCloud.apply(workspaceSnapshot)
        features.ngram.apply(workspaceSnapshot)
        features.kwic.apply(workspaceSnapshot)
        features.collocate.apply(workspaceSnapshot)

        if let restoredTab = WorkspaceDetailTab.fromSnapshotValue(workspaceSnapshot.currentTab) {
            features.shell.selectedTab = restoredTab.mainWorkspaceTab
        }

        let preferredFolderID = workspaceSnapshot.currentLibraryFolderId
        if preferredFolderID == "all" || preferredFolderID.isEmpty {
            features.library.selectFolder(nil)
        } else {
            features.library.selectFolder(preferredFolderID)
        }

        let preferredCorpusID = workspaceSnapshot.corpusIds.first
        if let preferredCorpusID,
           features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == preferredCorpusID }) {
            features.sidebar.selectedCorpusID = preferredCorpusID
            features.library.selectCorpus(preferredCorpusID)
            return
        }

        let preferredName = workspaceSnapshot.corpusNames.first
        if let preferredName,
           let matchingCorpus = features.sidebar.librarySnapshot.corpora.first(where: { $0.name == preferredName }) {
            features.sidebar.selectedCorpusID = matchingCorpus.id
            features.library.selectCorpus(matchingCorpus.id)
            return
        }

        if let currentSelection = features.sidebar.selectedCorpusID,
           features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == currentSelection }) {
            features.library.selectCorpus(currentSelection)
            return
        }

        let fallbackCorpusID = features.library.selectedFolderID == nil
            ? features.sidebar.librarySnapshot.corpora.first?.id
            : features.sidebar.librarySnapshot.corpora.first(where: { $0.folderId == features.library.selectedFolderID })?.id
        features.sidebar.selectedCorpusID = fallbackCorpusID
        features.library.selectCorpus(fallbackCorpusID)
    }

    private func resetFeatureResults(features: WorkspaceFeatureSet) {
        features.stats.reset()
        features.word.reset()
        features.tokenize.reset()
        features.topics.reset()
        features.compare.reset()
        features.chiSquare.reset()
        features.ngram.reset()
        features.wordCloud.reset()
        features.kwic.reset()
        features.collocate.reset()
        features.locator.reset()
    }

    private func syncFeatureContexts(features: WorkspaceFeatureSet) {
        let context = sceneStore.context
        features.shell.applyContext(context)
        features.sidebar.applyContext(context)
        features.library.applyContext(context)
        features.settings.applyContext(context)
    }

    private func performWorkspaceRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        features: WorkspaceFeatureSet,
        operation: () async throws -> Void
    ) async {
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
        } catch {
            features.sidebar.setError(error.localizedDescription)
            taskCenter.failTask(id: taskID, detail: error.localizedDescription)
        }
    }

    private func setBusy(_ isBusy: Bool, features: WorkspaceFeatureSet) {
        features.shell.isBusy = isBusy
        features.sidebar.setBusy(isBusy)
        features.library.setBusy(isBusy)
    }

    private func refreshRecentDocuments(features: WorkspaceFeatureSet) {
        guard let selectedCorpus = features.sidebar.selectedCorpus,
              let openedCorpus = sessionStore.openedCorpus else {
            return
        }
        do {
            let snapshot = try hostPreferencesStore.recordRecentDocument(
                corpusID: selectedCorpus.id,
                title: openedCorpus.displayName.isEmpty ? selectedCorpus.name : openedCorpus.displayName,
                subtitle: selectedCorpus.folderName,
                representedPath: openedCorpus.filePath
            )
            Task { await self.hostActionService.noteRecentDocument(path: openedCorpus.filePath) }
            features.settings.applyHostPreferences(snapshot)
        } catch {
            features.settings.setSupportStatus("最近打开写入失败：\(error.localizedDescription)")
        }
    }

    private func handleImportedCorpora(_ result: LibraryImportResult, features: WorkspaceFeatureSet) async throws {
        if let firstImported = result.importedItems.first {
            features.sidebar.selectedCorpusID = firstImported.id
            _ = try await libraryCoordinator.openSelection(selectedCorpusID: firstImported.id)
            applyWorkspacePresentation(features: features)
            persistWorkspaceState(features: features)
            syncWindowDocumentState(features: features)
        }
        features.library.setStatus("已导入 \(result.importedCount) 条语料。")
    }

    private func buildComparisonEntries(from selectedCorpora: [LibraryCorpusItem]) async throws -> [CompareRequestEntry] {
        var entries: [CompareRequestEntry] = []
        for corpus in selectedCorpora {
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

    private func makeSearchPersistenceState(features: WorkspaceFeatureSet) -> (
        query: String,
        options: SearchOptionsState,
        stopwordFilter: StopwordFilterState
    ) {
        switch features.shell.selectedTab {
        case .word:
            return (
                features.word.query.trimmingCharacters(in: .whitespacesAndNewlines),
                features.word.searchOptions,
                features.word.stopwordFilter
            )
        case .tokenize:
            return (
                features.tokenize.query.trimmingCharacters(in: .whitespacesAndNewlines),
                features.tokenize.searchOptions,
                features.tokenize.stopwordFilter
            )
        case .topics:
            return (
                features.topics.normalizedQuery,
                features.topics.searchOptions,
                features.topics.stopwordFilter
            )
        case .compare:
            return (
                features.compare.query.trimmingCharacters(in: .whitespacesAndNewlines),
                features.compare.searchOptions,
                features.compare.stopwordFilter
            )
        case .ngram:
            return (
                features.ngram.normalizedQuery,
                features.ngram.searchOptions,
                features.ngram.stopwordFilter
            )
        case .wordCloud:
            return (
                features.wordCloud.query.trimmingCharacters(in: .whitespacesAndNewlines),
                features.wordCloud.searchOptions,
                features.wordCloud.stopwordFilter
            )
        case .kwic:
            return (
                features.kwic.normalizedKeyword,
                features.kwic.searchOptions,
                features.kwic.stopwordFilter
            )
        case .collocate:
            return (
                features.collocate.normalizedKeyword,
                features.collocate.searchOptions,
                features.collocate.stopwordFilter
            )
        default:
            return ("", .default, .default)
        }
    }

    private func buildSceneGraph(features: WorkspaceFeatureSet) -> WorkspaceSceneGraph {
        let graphStore = WorkspaceSceneGraphStore()
        graphStore.sync(
            context: sceneStore.context,
            sidebar: features.sidebar.scene,
            shell: features.shell.scene,
            library: features.library.scene,
            settings: features.settings.scene,
            activeTab: features.shell.selectedTab,
            word: features.word.scene,
            tokenize: features.tokenize.scene,
            wordCloud: features.wordCloud.scene,
            stats: features.stats.scene,
            topics: features.topics.scene,
            compare: features.compare.scene,
            chiSquare: features.chiSquare.scene,
            ngram: features.ngram.scene,
            kwic: features.kwic.scene,
            collocate: features.collocate.scene,
            locator: features.locator.scene
        )
        return graphStore.graph
    }

    private func sceneStoreTopicsPageSize(_ features: WorkspaceFeatureSet) -> String {
        features.topics.scene?.controls.selectedPageSize.title(in: .system) ?? "50"
    }

    private func localizedTopicProgressDetail(_ progress: TopicAnalysisProgress) -> String {
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
}
