import Foundation

extension LibraryManagementCoordinator {
    func backupLibrary(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let destination = await dialogService.chooseDirectory(
            title: wordZText("选择备份位置", "Choose Backup Destination", mode: .system),
            message: wordZText("请选择 WordZ 备份输出目录。", "Choose a destination directory for the WordZ backup.", mode: .system),
            preferredRoute: preferredRoute
        ) else { return }
        let summary = try await repository.backupLibrary(destinationPath: destination)
        library.setStatus(
            l10nFormat(
                "备份完成：%d 条语料，输出到 %@。",
                table: "Errors",
                mode: .system,
                fallback: "Backup completed: %d corpora, written to %@.",
                summary.corpusCount,
                summary.backupDir
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func restoreLibrary(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let source = await dialogService.chooseDirectory(
            title: wordZText("选择备份目录", "Choose Backup Folder", mode: .system),
            message: wordZText("请选择要恢复的 WordZ 备份目录。", "Choose the WordZ backup folder to restore.", mode: .system),
            preferredRoute: preferredRoute
        ) else { return }
        let confirmed = await dialogService.confirm(
            title: wordZText("恢复备份", "Restore Backup", mode: .system),
            message: wordZText("会用备份目录覆盖当前本地语料库。", "The backup folder will replace the current local corpus library.", mode: .system),
            confirmTitle: wordZText("恢复", "Restore", mode: .system),
            preferredRoute: preferredRoute
        )
        guard confirmed else { return }
        let summary = try await repository.restoreLibrary(sourcePath: source)
        sessionStore.resetOpenedCorpus()
        sidebar.selectedCorpusID = nil
        library.setStatus(
            l10nFormat(
                "恢复完成：%d 条语料，来源 %@。",
                table: "Errors",
                mode: .system,
                fallback: "Restore completed: %d corpora, source %@.",
                summary.corpusCount,
                summary.restoredFromDir
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func repairLibrary(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        let summary = try await repository.repairLibrary()
        library.setStatus(
            l10nFormat(
                "修复完成：检查 %d 条语料，隔离 %d 条。",
                table: "Errors",
                mode: .system,
                fallback: "Repair completed: checked %d corpora, quarantined %d.",
                summary.checkedCorpora,
                summary.quarantinedCorpora
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func restoreSelectedRecycleEntry(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let entry = library.selectedRecycleEntry else { return }
        try await repository.restoreRecycleEntry(recycleEntryId: entry.recycleEntryId)
        library.setStatus(
            l10nFormat(
                "已恢复“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Restored \"%@\".",
                entry.name
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func purgeSelectedRecycleEntry(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let entry = library.selectedRecycleEntry else { return }
        let confirmed = await dialogService.confirm(
            title: wordZText("彻底删除回收站项目", "Permanently Delete Recycle Bin Item", mode: .system),
            message: l10nFormat(
                "“%@”将被永久移除。",
                table: "Errors",
                mode: .system,
                fallback: "\"%@\" will be removed permanently.",
                entry.name
            ),
            confirmTitle: wordZText("彻底删除", "Delete Permanently", mode: .system),
            preferredRoute: preferredRoute
        )
        guard confirmed else { return }
        try await repository.purgeRecycleEntry(recycleEntryId: entry.recycleEntryId)
        library.setStatus(
            l10nFormat(
                "已永久删除“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Permanently deleted \"%@\".",
                entry.name
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }
}
