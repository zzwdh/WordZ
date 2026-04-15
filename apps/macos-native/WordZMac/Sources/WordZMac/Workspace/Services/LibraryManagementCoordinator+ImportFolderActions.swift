import Foundation

extension LibraryManagementCoordinator {
    func importPaths(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws -> LibraryImportResult? {
        guard let paths = await dialogService.chooseImportPaths(preferredRoute: preferredRoute), !paths.isEmpty else { return nil }
        let result = try await repository.importCorpusPaths(
            paths,
            folderId: library.selectedFolderID ?? "",
            preserveHierarchy: library.preserveHierarchy
        )
        library.setStatus(
            l10nFormat(
                "已导入 %d 条语料，跳过 %d 条。",
                table: "Errors",
                mode: .system,
                fallback: "Imported %d corpora and skipped %d.",
                result.importedCount,
                result.skippedCount
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
        return result
    }

    func chooseImportPaths(preferredRoute: NativeWindowRoute? = nil) async -> [String]? {
        guard let paths = await dialogService.chooseImportPaths(preferredRoute: preferredRoute), !paths.isEmpty else { return nil }
        return paths
    }

    func createFolder(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let name = await dialogService.promptText(
            title: wordZText("新建文件夹", "New Folder", mode: .system),
            message: wordZText("输入新的语料文件夹名称。", "Enter a name for the new corpus folder.", mode: .system),
            defaultValue: "",
            confirmTitle: wordZText("创建", "Create", mode: .system),
            preferredRoute: preferredRoute
        ) else { return }
        _ = try await repository.createFolder(name: name)
        library.setStatus(
            l10nFormat(
                "已创建文件夹“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Created folder \"%@\".",
                name
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func renameSelectedFolder(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let folder = library.selectedFolder else { return }
        guard let newName = await dialogService.promptText(
            title: wordZText("重命名文件夹", "Rename Folder", mode: .system),
            message: l10nFormat(
                "输入“%@”的新名称。",
                table: "Errors",
                mode: .system,
                fallback: "Enter a new name for \"%@\".",
                folder.name
            ),
            defaultValue: folder.name,
            confirmTitle: wordZText("重命名", "Rename", mode: .system),
            preferredRoute: preferredRoute
        ) else { return }
        let updated = try await repository.renameFolder(folderId: folder.id, newName: newName)
        library.selectedFolderID = updated.id
        library.setStatus(
            l10nFormat(
                "已重命名文件夹为“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Renamed folder to \"%@\".",
                updated.name
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func deleteSelectedFolder(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let folder = library.selectedFolder else { return }
        let confirmed = await dialogService.confirm(
            title: wordZText("删除文件夹", "Delete Folder", mode: .system),
            message: l10nFormat(
                "文件夹“%@”会被移到回收站。",
                table: "Errors",
                mode: .system,
                fallback: "Folder \"%@\" will be moved to the recycle bin.",
                folder.name
            ),
            confirmTitle: wordZText("删除", "Delete", mode: .system),
            preferredRoute: preferredRoute
        )
        guard confirmed else { return }
        try await repository.deleteFolder(folderId: folder.id)
        library.selectedFolderID = nil
        library.setStatus(
            l10nFormat(
                "已删除文件夹“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Deleted folder \"%@\".",
                folder.name
            )
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }
}
