import Foundation

@MainActor
final class WorkspaceLibraryWorkflowService {
    let repository: any WorkspaceRepository
    let sessionStore: WorkspaceSessionStore
    let libraryCoordinator: any LibraryCoordinating
    let libraryManagementCoordinator: any LibraryManagementCoordinating
    let dialogService: NativeDialogServicing
    let taskCenter: NativeTaskCenter
    let persistenceWorkflow: WorkspacePersistenceWorkflowService

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        libraryCoordinator: any LibraryCoordinating,
        libraryManagementCoordinator: any LibraryManagementCoordinating,
        dialogService: NativeDialogServicing,
        taskCenter: NativeTaskCenter,
        persistenceWorkflow: WorkspacePersistenceWorkflowService
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.libraryCoordinator = libraryCoordinator
        self.libraryManagementCoordinator = libraryManagementCoordinator
        self.dialogService = dialogService
        self.taskCenter = taskCenter
        self.persistenceWorkflow = persistenceWorkflow
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

    func handleLibraryAction(
        _ action: LibraryManagementAction,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        do {
            let shouldTrackBusy = shouldTrackLibraryBusyState(for: action)
            if shouldTrackBusy {
                features.library.setBusy(true)
            }
            defer {
                if shouldTrackBusy {
                    features.library.setBusy(false)
                }
            }

            switch action {
            case .selectFolder,
                    .selectCorpusSet,
                    .selectCorpus,
                    .selectCorpusIDs,
                    .selectRecycleEntry,
                    .openSelectedCorpus,
                    .quickLookSelectedCorpus,
                    .shareSelectedCorpus,
                    .editSelectedCorpusMetadata,
                    .editSelectedCorporaMetadata:
                break
            case .refresh:
                try await libraryManagementCoordinator.refreshLibraryState(
                    into: features.library,
                    sidebar: features.sidebar
                )
            case .importPaths:
                await importCorpusFromDialog(
                    features: features,
                    preferredRoute: preferredRoute,
                    syncFeatureContexts: syncFeatureContexts
                )
            case .cleanSelectedCorpus:
                if let selectedCorpusID = features.library.selectedCorpusID {
                    await runCorpusCleaning(
                        [selectedCorpusID],
                        features: features,
                        syncFeatureContexts: syncFeatureContexts
                    )
                }
            case .cleanSelectedCorpora:
                await runCorpusCleaning(
                    features.library.selectedCorpora.map(\.id),
                    features: features,
                    syncFeatureContexts: syncFeatureContexts
                )
            case .createFolder:
                try await libraryManagementCoordinator.createFolder(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .saveCurrentCorpusSet:
                try await libraryManagementCoordinator.saveCurrentCorpusSet(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
                await persistenceWorkflow.persistRecentCorpusSetSelection(
                    features.library.selectedCorpusSetID,
                    features: features
                )
            case .renameSelectedCorpus:
                try await libraryManagementCoordinator.renameSelectedCorpus(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .moveSelectedCorpusToSelectedFolder:
                try await libraryManagementCoordinator.moveSelectedCorpusToFolder(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .deleteSelectedCorpus:
                try await libraryManagementCoordinator.deleteSelectedCorpus(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .showSelectedCorpusInfo:
                try await showSelectedCorpusInfo(features: features)
            case .saveSelectedCorpusMetadata(let metadata):
                try await libraryManagementCoordinator.updateSelectedCorpusMetadata(
                    metadata,
                    settings: features.settings,
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .applySelectedCorporaMetadataPatch(let patch):
                try await libraryManagementCoordinator.updateSelectedCorporaMetadata(
                    patch,
                    settings: features.settings,
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .renameSelectedFolder:
                try await libraryManagementCoordinator.renameSelectedFolder(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .deleteSelectedFolder:
                try await libraryManagementCoordinator.deleteSelectedFolder(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .deleteSelectedCorpusSet:
                try await libraryManagementCoordinator.deleteSelectedCorpusSet(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .backupLibrary:
                try await libraryManagementCoordinator.backupLibrary(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .restoreLibrary:
                try await libraryManagementCoordinator.restoreLibrary(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .repairLibrary:
                try await libraryManagementCoordinator.repairLibrary(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .restoreSelectedRecycleEntry:
                try await libraryManagementCoordinator.restoreSelectedRecycleEntry(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .purgeSelectedRecycleEntry:
                try await libraryManagementCoordinator.purgeSelectedRecycleEntry(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            }

            applyWorkspacePresentation(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            features.sidebar.clearError()
        } catch {
            features.library.setError(error.localizedDescription)
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func showSelectedCorpusInfo(features: WorkspaceFeatureSet) async throws {
        guard let selectedCorpus = features.library.selectedCorpus ?? features.sidebar.selectedCorpus else {
            return
        }
        let summary = try await repository.loadCorpusInfo(corpusId: selectedCorpus.id)
        features.library.presentCorpusInfo(features.library.makeCorpusInfoScene(summary: summary))
        features.library.setStatus(wordZText("已载入语料信息。", "Loaded corpus information.", mode: .system))
    }

    func importCorpusFromDialog(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        guard let paths = await libraryManagementCoordinator.chooseImportPaths(preferredRoute: preferredRoute) else {
            return
        }
        await runLibraryImport(
            paths,
            folderId: features.library.selectedFolderID ?? "",
            preserveHierarchy: features.library.preserveHierarchy,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func importExternalPaths(
        _ paths: [String],
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        guard !paths.isEmpty else { return }
        await runLibraryImport(
            paths,
            folderId: features.library.selectedFolderID ?? "",
            preserveHierarchy: false,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func handleImportedCorpora(
        _ result: LibraryImportResult,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws {
        if let firstImported = result.importedItems.first {
            features.sidebar.selectedCorpusID = firstImported.id
            _ = try await libraryCoordinator.openSelection(selectedCorpusID: firstImported.id)
            applyWorkspacePresentation(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            persistenceWorkflow.persistWorkspaceState(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            persistenceWorkflow.syncWindowDocumentState(features: features)
        }
        features.library.setStatus("已导入 \(result.importedCount) 条语料。")
    }

    func runLibraryImport(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        guard !paths.isEmpty else { return }

        var taskID: UUID?
        do {
            setBusy(true, features: features)
            defer {
                setBusy(false, features: features)
                features.library.setImportProgress(nil)
            }

            let createdTaskID = taskCenter.beginTask(
                title: wordZText("导入语料", "Import Corpora", mode: .system),
                detail: wordZText("正在准备导入语料…", "Preparing corpus import…", mode: .system),
                progress: 0
            )
            taskID = createdTaskID

            let importTask = Task { () throws -> LibraryImportResult in
                if let progressRepository = repository as? LibraryImportProgressReportingRepository {
                    return try await progressRepository.importCorpusPaths(
                        paths,
                        folderId: folderId,
                        preserveHierarchy: preserveHierarchy
                    ) { [weak taskCenter] snapshot in
                        Task { @MainActor in
                            let detail = self.localizedLibraryImportStatus(snapshot)
                            features.library.setImportProgress(snapshot)
                            features.library.setStatus(detail)
                            taskCenter?.updateTask(
                                id: createdTaskID,
                                detail: detail,
                                progress: snapshot.progress
                            )
                        }
                    }
                }
                return try await repository.importCorpusPaths(
                    paths,
                    folderId: folderId,
                    preserveHierarchy: preserveHierarchy
                )
            }

            taskCenter.registerCancelHandler(id: createdTaskID) {
                importTask.cancel()
            }

            let result = try await importTask.value
            try await libraryManagementCoordinator.refreshLibraryState(
                into: features.library,
                sidebar: features.sidebar
            )
            try await handleImportedCorpora(
                result,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            features.library.presentImportSummary(
                features.library.makeImportSummaryScene(result: result)
            )
            let completionDetail = localizedLibraryImportCompletion(result)
            features.library.setStatus(completionDetail)
            features.sidebar.clearError()
            taskCenter.completeTask(id: createdTaskID, detail: completionDetail)
        } catch is CancellationError {
            features.library.setStatus(wordZText("导入已取消。", "Import cancelled.", mode: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
            features.library.setError(error.localizedDescription)
            if let taskID {
                taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            }
        }
    }

    func runCorpusCleaning(
        _ corpusIds: [String],
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let requestedCorpusIDs = Array(Set(corpusIds)).sorted()
        guard !requestedCorpusIDs.isEmpty else { return }

        var taskID: UUID?
        do {
            setBusy(true, features: features)
            defer {
                setBusy(false, features: features)
            }

            let createdTaskID = taskCenter.beginTask(
                title: wordZText("语料自动清洗", "Corpus Auto-Cleaning", mode: .system),
                detail: wordZText("正在准备自动清洗…", "Preparing auto-cleaning…", mode: .system),
                progress: 0
            )
            taskID = createdTaskID

            let cleaningTask = Task { () throws -> LibraryCorpusCleaningBatchResult in
                if let progressRepository = repository as? LibraryCorpusCleaningProgressReportingRepository {
                    return try await progressRepository.cleanCorpora(corpusIds: requestedCorpusIDs) { [weak taskCenter] snapshot in
                        Task { @MainActor in
                            let detail = self.localizedLibraryCleaningStatus(snapshot)
                            features.library.setStatus(detail)
                            taskCenter?.updateTask(
                                id: createdTaskID,
                                detail: detail,
                                progress: snapshot.progress
                            )
                        }
                    }
                }
                return try await repository.cleanCorpora(corpusIds: requestedCorpusIDs)
            }

            taskCenter.registerCancelHandler(id: createdTaskID) {
                cleaningTask.cancel()
            }

            let result = try await cleaningTask.value
            try await libraryManagementCoordinator.refreshLibraryState(
                into: features.library,
                sidebar: features.sidebar
            )
            try await reloadOpenedCorpusIfNeeded(
                afterCleaning: result,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )

            let completionDetail = localizedLibraryCleaningCompletion(result)
            features.library.setStatus(completionDetail)
            features.sidebar.clearError()
            taskCenter.completeTask(id: createdTaskID, detail: completionDetail)
        } catch is CancellationError {
            features.library.setStatus(wordZText("自动清洗已取消。", "Auto-cleaning cancelled.", mode: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
            features.library.setError(error.localizedDescription)
            if let taskID {
                taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            }
        }
    }

    private func shouldTrackLibraryBusyState(for action: LibraryManagementAction) -> Bool {
        switch action {
        case .refresh,
                .selectFolder,
                .selectCorpusSet,
                .selectCorpus,
                .selectCorpusIDs,
                .selectRecycleEntry,
                .openSelectedCorpus,
                .quickLookSelectedCorpus,
                .shareSelectedCorpus,
                .cleanSelectedCorpus,
                .cleanSelectedCorpora,
                .editSelectedCorpusMetadata,
                .editSelectedCorporaMetadata,
                .importPaths:
            return false
        default:
            return true
        }
    }

    private func applyWorkspacePresentation(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) {
        persistenceWorkflow.applyWorkspacePresentation(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    private func reloadOpenedCorpusIfNeeded(
        afterCleaning result: LibraryCorpusCleaningBatchResult,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws {
        guard let openedCorpusSourceID = sessionStore.openedCorpusSourceID else { return }
        let cleanedCorpusIDs = Set(result.cleanedItems.map(\.id))
        guard cleanedCorpusIDs.contains(openedCorpusSourceID) else { return }

        _ = try await libraryCoordinator.openSelection(selectedCorpusID: openedCorpusSourceID)
        applyWorkspacePresentation(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        persistenceWorkflow.persistWorkspaceState(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        persistenceWorkflow.syncWindowDocumentState(features: features)
    }

    private func setBusy(_ isBusy: Bool, features: WorkspaceFeatureSet) {
        features.shell.isBusy = isBusy
        features.sidebar.setBusy(isBusy)
        features.library.setBusy(isBusy)
    }

    private func localizedLibraryImportStatus(_ snapshot: LibraryImportProgressSnapshot) -> String {
        switch snapshot.phase {
        case .preparing:
            return wordZText("正在准备导入…", "Preparing import…", mode: .system)
        case .importing:
            let currentName = snapshot.currentName.isEmpty
                ? wordZText("当前文件", "current file", mode: .system)
                : snapshot.currentName
            return "\(wordZText("正在导入", "Importing", mode: .system)) \(currentName) · \(snapshot.completedCount) / \(snapshot.totalCount)"
        case .committing:
            return wordZText("正在提交导入结果…", "Committing imported corpora…", mode: .system)
        case .completed:
            return wordZText("导入完成。", "Import completed.", mode: .system)
        }
    }

    private func localizedLibraryImportCompletion(_ result: LibraryImportResult) -> String {
        var summary = String(
            format: wordZText(
                "已导入 %d 条语料，跳过 %d 条，已清洗 %d 条，其中 %d 条有变更。",
                "Imported %d corpora, skipped %d, cleaned %d, and %d changed.",
                mode: .system
            ),
            result.importedCount,
            result.skippedCount,
            result.cleaningSummary.cleanedCount,
            result.cleaningSummary.changedCount
        )
        let cleaningHitsSummary = localizedCleaningRuleHitsSummary(result.cleaningSummary.ruleHits)
        if !cleaningHitsSummary.isEmpty {
            summary += " \(cleaningHitsSummary)"
        }
        if let firstFailure = result.failureItems.first {
            summary += " \(wordZText("首个失败项：", "First failure: ", mode: .system))\(firstFailure.fileName) (\(firstFailure.reason))"
        }
        return summary
    }

    private func localizedLibraryCleaningStatus(_ snapshot: LibraryCorpusCleaningProgressSnapshot) -> String {
        switch snapshot.phase {
        case .preparing:
            return wordZText("正在准备自动清洗…", "Preparing auto-cleaning…", mode: .system)
        case .cleaning:
            let currentName = snapshot.currentCorpusName.isEmpty
                ? wordZText("当前语料", "current corpus", mode: .system)
                : snapshot.currentCorpusName
            return "\(wordZText("正在清洗", "Cleaning", mode: .system)) \(currentName) · \(snapshot.completedCount) / \(snapshot.totalCount)"
        case .committing:
            return wordZText("正在写回清洗结果…", "Writing cleaned corpora…", mode: .system)
        case .completed:
            return wordZText("自动清洗完成。", "Auto-cleaning completed.", mode: .system)
        }
    }

    private func localizedLibraryCleaningCompletion(_ result: LibraryCorpusCleaningBatchResult) -> String {
        var summary = String(
            format: wordZText(
                "已清洗 %d / %d 条语料，其中 %d 条有变更。",
                "Cleaned %d / %d corpora, with %d changed.",
                mode: .system
            ),
            result.cleanedCount,
            result.requestedCount,
            result.changedCount
        )
        let cleaningHitsSummary = localizedCleaningRuleHitsSummary(result.ruleHits)
        if !cleaningHitsSummary.isEmpty {
            summary += " \(cleaningHitsSummary)"
        }
        if let firstFailure = result.failureItems.first {
            summary += " \(wordZText("首个失败项：", "First failure: ", mode: .system))\(firstFailure.corpusName) (\(firstFailure.reason))"
        }
        return summary
    }

    private func localizedCleaningRuleHitsSummary(_ ruleHits: [LibraryCorpusCleaningRuleHit]) -> String {
        guard !ruleHits.isEmpty else { return "" }
        let summary = ruleHits.prefix(3)
            .map { "\($0.title(in: .system)) \($0.count)" }
            .joined(separator: " · ")
        return "\(wordZText("规则命中：", "Rule hits: ", mode: .system))\(summary)"
    }
}
