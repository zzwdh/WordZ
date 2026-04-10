import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func exportCurrent(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            let savedPath: String?
            if features.shell.selectedTab == .tokenize,
               let document = features.tokenize.exportDocument {
                savedPath = try await exportCoordinator.export(
                    textDocument: document,
                    title: wordZText("导出分词结果", "Export Tokenized Text", mode: .system),
                    preferredRoute: preferredRoute
                )
            } else {
                let graph = buildSceneGraph(features: features)
                savedPath = try await exportCoordinator.exportActiveScene(
                    graph: graph,
                    preferredRoute: preferredRoute
                )
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
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            if let savedPath = try await exportCoordinator.export(
                textDocument: document,
                title: title,
                preferredRoute: preferredRoute
            ) {
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
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            if let savedPath = try await exportCoordinator.export(
                snapshot: snapshot,
                title: title,
                preferredRoute: preferredRoute
            ) {
                features.library.setStatus("\(successStatus) \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func importCorpusFromDialog(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let paths = await libraryManagementCoordinator.chooseImportPaths(preferredRoute: preferredRoute) else { return }
        await runLibraryImport(
            paths,
            folderId: features.library.selectedFolderID ?? "",
            preserveHierarchy: features.library.preserveHierarchy,
            features: features
        )
    }

    func importExternalPaths(_ paths: [String], features: WorkspaceFeatureSet) async {
        guard !paths.isEmpty else { return }
        await runLibraryImport(
            paths,
            folderId: features.library.selectedFolderID ?? "",
            preserveHierarchy: false,
            features: features
        )
    }

    func handleImportedCorpora(_ result: LibraryImportResult, features: WorkspaceFeatureSet) async throws {
        if let firstImported = result.importedItems.first {
            features.sidebar.selectedCorpusID = firstImported.id
            _ = try await libraryCoordinator.openSelection(selectedCorpusID: firstImported.id)
            applyWorkspacePresentation(features: features)
            persistWorkspaceState(features: features)
            syncWindowDocumentState(features: features)
        }
        features.library.setStatus("已导入 \(result.importedCount) 条语料。")
    }

    func runLibraryImport(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool,
        features: WorkspaceFeatureSet
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
                            features.library.setImportProgress(snapshot)
                            features.library.setStatus(self.localizedLibraryImportStatus(snapshot))
                            taskCenter?.updateTask(
                                id: createdTaskID,
                                detail: self.localizedLibraryImportStatus(snapshot),
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
            try await libraryManagementCoordinator.refreshLibraryState(into: features.library, sidebar: features.sidebar)
            try await handleImportedCorpora(result, features: features)
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
                "已导入 %d 条语料，跳过 %d 条。",
                "Imported %d corpora and skipped %d.",
                mode: .system
            ),
            result.importedCount,
            result.skippedCount
        )
        if let firstFailure = result.failureItems.first {
            summary += " \(wordZText("首个失败项：", "First failure: ", mode: .system))\(firstFailure.fileName) (\(firstFailure.reason))"
        }
        return summary
    }

    func buildSceneGraph(features: WorkspaceFeatureSet) -> WorkspaceSceneGraph {
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
            stats: features.stats.scene,
            topics: features.topics.scene,
            compare: features.compare.scene,
            keyword: features.keyword.scene,
            chiSquare: features.chiSquare.scene,
            ngram: features.ngram.scene,
            kwic: features.kwic.scene,
            collocate: features.collocate.scene,
            locator: features.locator.scene
        )
        return graphStore.graph
    }
}
