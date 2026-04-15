import Foundation

extension LibraryManagementCoordinator {
    func renameSelectedCorpus(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        guard let newName = await dialogService.promptText(
            title: wordZText("重命名语料", "Rename Corpus", mode: .system),
            message: l10nFormat(
                "输入“%@”的新名称。",
                table: "Errors",
                mode: .system,
                fallback: "Enter a new name for \"%@\".",
                selectedCorpus.name
            ),
            defaultValue: selectedCorpus.name,
            confirmTitle: wordZText("重命名", "Rename", mode: .system),
            preferredRoute: preferredRoute
        ) else { return }
        let updated = try await repository.renameCorpus(corpusId: selectedCorpus.id, newName: newName)
        sidebar.selectedCorpusID = updated.id
        library.setStatus(
            l10nFormat(
                "已重命名语料为“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Renamed corpus to \"%@\".",
                updated.name
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func updateSelectedCorpusMetadata(
        _ metadata: CorpusMetadataProfile,
        settings: WorkspaceSettingsViewModel,
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        let updated = try await repository.updateCorpusMetadata(corpusId: selectedCorpus.id, metadata: metadata)
        await persistRecentMetadataSourceLabelIfNeeded(
            metadata.sourceLabel,
            settings: settings,
            sidebar: sidebar
        )
        sidebar.selectedCorpusID = updated.id
        library.dismissMetadataEditor()
        library.setStatus(
            l10nFormat(
                "已更新“%@”的语料元数据。",
                table: "Errors",
                mode: .system,
                fallback: "Updated corpus metadata for \"%@\".",
                updated.name
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
        if library.corpusInfoSheet?.id == updated.id {
            let summary = try await repository.loadCorpusInfo(corpusId: updated.id)
            library.presentCorpusInfo(library.makeCorpusInfoScene(summary: summary))
        }
    }

    func updateSelectedCorporaMetadata(
        _ patch: BatchCorpusMetadataPatch,
        settings: WorkspaceSettingsViewModel,
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard patch.hasChanges else { return }
        let targetCorpora = library.selectedCorpora
        guard !targetCorpora.isEmpty else { return }

        for corpus in targetCorpora {
            let updatedMetadata = patch.applying(to: corpus.metadata)
            _ = try await repository.updateCorpusMetadata(corpusId: corpus.id, metadata: updatedMetadata)
        }

        await persistRecentMetadataSourceLabelIfNeeded(
            patch.sourceLabel ?? "",
            settings: settings,
            sidebar: sidebar
        )
        library.dismissMetadataEditor()
        library.setStatus(
            l10nFormat(
                "已批量更新 %d 条语料。",
                table: "Errors",
                mode: .system,
                fallback: "Updated metadata for %d corpora.",
                targetCorpora.count
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func moveSelectedCorpusToFolder(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        let targetFolderID = library.selectedFolderID ?? ""
        guard targetFolderID != selectedCorpus.folderId else { return }
        _ = try await repository.moveCorpus(corpusId: selectedCorpus.id, targetFolderId: targetFolderID)
        library.setStatus(
            l10nFormat(
                "已移动语料“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Moved corpus \"%@\".",
                selectedCorpus.name
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func deleteSelectedCorpus(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        let confirmed = await dialogService.confirm(
            title: wordZText("删除语料", "Delete Corpus", mode: .system),
            message: l10nFormat(
                "“%@”会被移到回收站。",
                table: "Errors",
                mode: .system,
                fallback: "\"%@\" will be moved to the recycle bin.",
                selectedCorpus.name
            ),
            confirmTitle: wordZText("删除", "Delete", mode: .system),
            preferredRoute: preferredRoute
        )
        guard confirmed else { return }
        try await repository.deleteCorpus(corpusId: selectedCorpus.id)
        if sessionStore.matchesOpenedCorpusSource(selectedCorpus.id) {
            sessionStore.resetOpenedCorpus()
        }
        sidebar.selectedCorpusID = nil
        library.setStatus(
            l10nFormat(
                "已删除语料“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Deleted corpus \"%@\".",
                selectedCorpus.name
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    private func persistRecentMetadataSourceLabelIfNeeded(
        _ sourceLabel: String,
        settings: WorkspaceSettingsViewModel,
        sidebar: LibrarySidebarViewModel
    ) async {
        let currentSnapshot = settings.exportSnapshot()
        let nextRecentLabels = MetadataSourcePresetSupport.updatedRecentSourceLabels(
            current: currentSnapshot.recentMetadataSourceLabels,
            newLabel: sourceLabel
        )

        guard nextRecentLabels != currentSnapshot.recentMetadataSourceLabels else { return }

        let nextSnapshot = UISettingsSnapshot(
            showWelcomeScreen: currentSnapshot.showWelcomeScreen,
            restoreWorkspace: currentSnapshot.restoreWorkspace,
            debugLogging: currentSnapshot.debugLogging,
            recentMetadataSourceLabels: nextRecentLabels
        )

        do {
            try await repository.saveUISettings(nextSnapshot)
            settings.applyRecentMetadataSourceLabels(nextRecentLabels)
            sidebar.applyRecentMetadataSourceLabels(nextRecentLabels)
        } catch {
            return
        }
    }
}
