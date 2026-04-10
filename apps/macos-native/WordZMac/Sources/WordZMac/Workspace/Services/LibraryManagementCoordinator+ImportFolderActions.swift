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
        library.setStatus("已导入 \(result.importedCount) 条语料，跳过 \(result.skippedCount) 条。")
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
            title: "新建文件夹",
            message: "输入新的语料文件夹名称。",
            defaultValue: "",
            confirmTitle: "创建",
            preferredRoute: preferredRoute
        ) else { return }
        _ = try await repository.createFolder(name: name)
        library.setStatus("已创建文件夹“\(name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func renameSelectedFolder(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let folder = library.selectedFolder else { return }
        guard let newName = await dialogService.promptText(
            title: "重命名文件夹",
            message: "输入“\(folder.name)”的新名称。",
            defaultValue: folder.name,
            confirmTitle: "重命名",
            preferredRoute: preferredRoute
        ) else { return }
        let updated = try await repository.renameFolder(folderId: folder.id, newName: newName)
        library.selectedFolderID = updated.id
        library.setStatus("已重命名文件夹为“\(updated.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func deleteSelectedFolder(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let folder = library.selectedFolder else { return }
        let confirmed = await dialogService.confirm(
            title: "删除文件夹",
            message: "文件夹“\(folder.name)”会被移到回收站。",
            confirmTitle: "删除",
            preferredRoute: preferredRoute
        )
        guard confirmed else { return }
        try await repository.deleteFolder(folderId: folder.id)
        library.selectedFolderID = nil
        library.setStatus("已删除文件夹“\(folder.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }
}
