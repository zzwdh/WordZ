import Foundation

extension LibraryManagementCoordinator {
    func backupLibrary(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let destination = await dialogService.chooseDirectory(
            title: "选择备份位置",
            message: "请选择 WordZ 备份输出目录。",
            preferredRoute: preferredRoute
        ) else { return }
        let summary = try await repository.backupLibrary(destinationPath: destination)
        library.setStatus("备份完成：\(summary.corpusCount) 条语料，输出到 \(summary.backupDir)。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func restoreLibrary(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let source = await dialogService.chooseDirectory(
            title: "选择备份目录",
            message: "请选择要恢复的 WordZ 备份目录。",
            preferredRoute: preferredRoute
        ) else { return }
        let confirmed = await dialogService.confirm(
            title: "恢复备份",
            message: "会用备份目录覆盖当前本地语料库。",
            confirmTitle: "恢复",
            preferredRoute: preferredRoute
        )
        guard confirmed else { return }
        let summary = try await repository.restoreLibrary(sourcePath: source)
        sessionStore.resetOpenedCorpus()
        sidebar.selectedCorpusID = nil
        library.setStatus("恢复完成：\(summary.corpusCount) 条语料，来源 \(summary.restoredFromDir)。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func repairLibrary(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        let summary = try await repository.repairLibrary()
        library.setStatus("修复完成：检查 \(summary.checkedCorpora) 条语料，隔离 \(summary.quarantinedCorpora) 条。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func restoreSelectedRecycleEntry(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let entry = library.selectedRecycleEntry else { return }
        try await repository.restoreRecycleEntry(recycleEntryId: entry.recycleEntryId)
        library.setStatus("已恢复“\(entry.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func purgeSelectedRecycleEntry(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let entry = library.selectedRecycleEntry else { return }
        let confirmed = await dialogService.confirm(
            title: "彻底删除回收站项目",
            message: "“\(entry.name)”将被永久移除。",
            confirmTitle: "彻底删除",
            preferredRoute: preferredRoute
        )
        guard confirmed else { return }
        try await repository.purgeRecycleEntry(recycleEntryId: entry.recycleEntryId)
        library.setStatus("已永久删除“\(entry.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }
}
