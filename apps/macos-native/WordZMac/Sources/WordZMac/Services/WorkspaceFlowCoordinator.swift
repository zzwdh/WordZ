import AppKit
import Foundation

@MainActor
final class WorkspaceFlowCoordinator {
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
        libraryCoordinator: LibraryCoordinator
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
        do {
            let corpus = try await ensureOpenedCorpus(features: features)
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let result = try await repository.runStats(text: corpus.content)
            features.stats.apply(result)
            features.word.apply(result)
            features.shell.selectedTab = .stats
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runWord(features: WorkspaceFeatureSet) async {
        do {
            let corpus = try await ensureOpenedCorpus(features: features)
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let result = try await repository.runStats(text: corpus.content)
            features.stats.apply(result)
            features.word.apply(result)
            features.shell.selectedTab = .word
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runCompare(features: WorkspaceFeatureSet) async {
        let selectedCorpora = features.compare.selectedCorpusItems()
        guard selectedCorpora.count >= 2 else {
            features.sidebar.setError("Compare 至少需要选择 2 条语料。")
            return
        }

        setBusy(true, features: features)
        defer { setBusy(false, features: features) }

        do {
            let comparisonEntries = try await buildComparisonEntries(from: selectedCorpora)
            let result = try await repository.runCompare(comparisonEntries: comparisonEntries)
            features.compare.apply(result)
            features.shell.selectedTab = .compare
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runChiSquare(features: WorkspaceFeatureSet) async {
        do {
            let inputs = try features.chiSquare.validatedInputs()
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let result = try await repository.runChiSquare(
                a: inputs.0,
                b: inputs.1,
                c: inputs.2,
                d: inputs.3,
                yates: features.chiSquare.useYates
            )
            features.chiSquare.apply(result)
            features.shell.selectedTab = .chiSquare
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
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

        do {
            let corpus = try await ensureOpenedCorpus(features: features)
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let result = try await repository.runKWIC(
                text: corpus.content,
                keyword: keyword,
                leftWindow: features.kwic.leftWindowValue,
                rightWindow: features.kwic.rightWindowValue,
                searchOptions: features.kwic.searchOptions
            )
            features.kwic.apply(result)
            features.shell.selectedTab = .kwic
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runNgram(features: WorkspaceFeatureSet) async {
        do {
            let corpus = try await ensureOpenedCorpus(features: features)
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let result = try await repository.runNgram(
                text: corpus.content,
                n: features.ngram.ngramSizeValue
            )
            features.ngram.apply(result)
            features.shell.selectedTab = .ngram
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runWordCloud(features: WorkspaceFeatureSet) async {
        do {
            let corpus = try await ensureOpenedCorpus(features: features)
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let result = try await repository.runWordCloud(text: corpus.content, limit: features.wordCloud.limit)
            features.wordCloud.apply(result)
            features.shell.selectedTab = .wordCloud
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runCollocate(features: WorkspaceFeatureSet) async {
        let keyword = features.collocate.normalizedKeyword
        guard !keyword.isEmpty else {
            features.sidebar.setError("请输入 Collocate 节点词。")
            return
        }

        do {
            let corpus = try await ensureOpenedCorpus(features: features)
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let result = try await repository.runCollocate(
                text: corpus.content,
                keyword: keyword,
                leftWindow: features.collocate.leftWindowValue,
                rightWindow: features.collocate.rightWindowValue,
                minFreq: features.collocate.minFreqValue,
                searchOptions: features.collocate.searchOptions
            )
            features.collocate.apply(result)
            features.shell.selectedTab = .collocate
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func runLocator(features: WorkspaceFeatureSet) async {
        guard let source = features.locator.currentSource ?? features.kwic.primaryLocatorSource else {
            features.sidebar.setError("请先运行 KWIC，Locator 会默认定位第一条结果。")
            return
        }

        do {
            let corpus = try await ensureOpenedCorpus(features: features)
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let result = try await repository.runLocator(
                text: corpus.content,
                sentenceId: source.sentenceId,
                nodeIndex: source.nodeIndex,
                leftWindow: features.locator.leftWindowValue,
                rightWindow: features.locator.rightWindowValue
            )
            features.locator.apply(result, source: source)
            features.shell.selectedTab = .locator
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
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
            features.library.setBusy(true)
            defer { features.library.setBusy(false) }
            switch action {
            case .selectFolder, .selectCorpus, .selectRecycleEntry, .openSelectedCorpus:
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

    func exportCurrent(features: WorkspaceFeatureSet) async {
        do {
            let graph = buildSceneGraph(features: features)
            if let savedPath = try await exportCoordinator.exportActiveScene(graph: graph) {
                features.library.setStatus("已导出到 \(savedPath)")
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
        features.shell.selectedTab = .library
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
            features.compare.reset()
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
        let searchState = makeSearchPersistenceState(features: features)
        let draft = workspacePersistence.buildDraft(
            selectedTab: features.shell.selectedTab,
            selectedFolderID: features.library.selectedFolderID ?? "all",
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            searchQuery: searchState.query,
            searchOptions: searchState.options,
            stopwordFilter: searchState.stopwordFilter,
            ngramSize: features.ngram.ngramSize,
            ngramPageSize: features.ngram.pageSizeSnapshotValue,
            kwicLeftWindow: features.kwic.leftWindow,
            kwicRightWindow: features.kwic.rightWindow,
            collocateLeftWindow: features.collocate.leftWindow,
            collocateRightWindow: features.collocate.rightWindow,
            collocateMinFreq: features.collocate.minFreq
        )

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

    private func applyWorkspaceSnapshot(_ workspaceSnapshot: WorkspaceSnapshotSummary, features: WorkspaceFeatureSet) {
        features.word.apply(workspaceSnapshot)
        features.compare.apply(workspaceSnapshot)
        features.wordCloud.apply(workspaceSnapshot)
        features.ngram.apply(workspaceSnapshot)
        features.kwic.apply(workspaceSnapshot)
        features.collocate.apply(workspaceSnapshot)

        if let restoredTab = WorkspaceDetailTab.fromSnapshotValue(workspaceSnapshot.currentTab) {
            features.shell.selectedTab = restoredTab
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
            wordCloud: features.wordCloud.scene,
            stats: features.stats.scene,
            compare: features.compare.scene,
            chiSquare: features.chiSquare.scene,
            ngram: features.ngram.scene,
            kwic: features.kwic.scene,
            collocate: features.collocate.scene,
            locator: features.locator.scene
        )
        return graphStore.graph
    }
}
