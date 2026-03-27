import AppKit
import Foundation

@MainActor
final class LibraryManagementCoordinator {
    private let repository: any WorkspaceRepository
    private let dialogService: NativeDialogServicing
    private let sessionStore: WorkspaceSessionStore

    init(
        repository: any WorkspaceRepository,
        dialogService: NativeDialogServicing,
        sessionStore: WorkspaceSessionStore
    ) {
        self.repository = repository
        self.dialogService = dialogService
        self.sessionStore = sessionStore
    }

    func attach(window: AnyObject?) {
        dialogService.attach(window: window as? NSWindow)
    }

    func refreshLibraryState(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        let nextLibrary = try await repository.listLibrary(folderId: "all")
        let nextRecycle = try await repository.listRecycleBin()
        sidebar.librarySnapshot = nextLibrary
        library.applyLibrarySnapshot(nextLibrary)
        library.applyRecycleSnapshot(nextRecycle)
        library.syncSidebarSelection(sidebar.selectedCorpusID)
    }

    func importPaths(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws -> LibraryImportResult? {
        guard let paths = await dialogService.chooseImportPaths(), !paths.isEmpty else { return nil }
        let result = try await repository.importCorpusPaths(
            paths,
            folderId: library.selectedFolderID ?? "",
            preserveHierarchy: library.preserveHierarchy
        )
        library.setStatus("已导入 \(result.importedCount) 条语料，跳过 \(result.skippedCount) 条。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
        return result
    }

    func createFolder(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let name = await dialogService.promptText(
            title: "新建文件夹",
            message: "输入新的语料文件夹名称。",
            defaultValue: "",
            confirmTitle: "创建"
        ) else { return }
        _ = try await repository.createFolder(name: name)
        library.setStatus("已创建文件夹“\(name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func renameSelectedCorpus(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        guard let newName = await dialogService.promptText(
            title: "重命名语料",
            message: "输入“\(selectedCorpus.name)”的新名称。",
            defaultValue: selectedCorpus.name,
            confirmTitle: "重命名"
        ) else { return }
        let updated = try await repository.renameCorpus(corpusId: selectedCorpus.id, newName: newName)
        sidebar.selectedCorpusID = updated.id
        library.setStatus("已重命名语料为“\(updated.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func moveSelectedCorpusToFolder(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        let targetFolderID = library.selectedFolderID ?? ""
        guard targetFolderID != selectedCorpus.folderId else { return }
        _ = try await repository.moveCorpus(corpusId: selectedCorpus.id, targetFolderId: targetFolderID)
        library.setStatus("已移动语料“\(selectedCorpus.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func deleteSelectedCorpus(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        let confirmed = await dialogService.confirm(
            title: "删除语料",
            message: "“\(selectedCorpus.name)”会被移到回收站。",
            confirmTitle: "删除"
        )
        guard confirmed else { return }
        try await repository.deleteCorpus(corpusId: selectedCorpus.id)
        if sessionStore.matchesOpenedCorpusSource(selectedCorpus.id) {
            sessionStore.resetOpenedCorpus()
        }
        sidebar.selectedCorpusID = nil
        library.setStatus("已删除语料“\(selectedCorpus.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func renameSelectedFolder(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let folder = library.selectedFolder else { return }
        guard let newName = await dialogService.promptText(
            title: "重命名文件夹",
            message: "输入“\(folder.name)”的新名称。",
            defaultValue: folder.name,
            confirmTitle: "重命名"
        ) else { return }
        let updated = try await repository.renameFolder(folderId: folder.id, newName: newName)
        library.selectedFolderID = updated.id
        library.setStatus("已重命名文件夹为“\(updated.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func deleteSelectedFolder(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let folder = library.selectedFolder else { return }
        let confirmed = await dialogService.confirm(
            title: "删除文件夹",
            message: "文件夹“\(folder.name)”会被移到回收站。",
            confirmTitle: "删除"
        )
        guard confirmed else { return }
        try await repository.deleteFolder(folderId: folder.id)
        library.selectedFolderID = nil
        library.setStatus("已删除文件夹“\(folder.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func backupLibrary(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let destination = await dialogService.chooseDirectory(
            title: "选择备份位置",
            message: "请选择 WordZ 备份输出目录。"
        ) else { return }
        let summary = try await repository.backupLibrary(destinationPath: destination)
        library.setStatus("备份完成：\(summary.corpusCount) 条语料，输出到 \(summary.backupDir)。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func restoreLibrary(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let source = await dialogService.chooseDirectory(
            title: "选择备份目录",
            message: "请选择要恢复的 WordZ 备份目录。"
        ) else { return }
        let confirmed = await dialogService.confirm(
            title: "恢复备份",
            message: "会用备份目录覆盖当前本地语料库。",
            confirmTitle: "恢复"
        )
        guard confirmed else { return }
        let summary = try await repository.restoreLibrary(sourcePath: source)
        sessionStore.resetOpenedCorpus()
        sidebar.selectedCorpusID = nil
        library.setStatus("恢复完成：\(summary.corpusCount) 条语料，来源 \(summary.restoredFromDir)。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func repairLibrary(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        let summary = try await repository.repairLibrary()
        library.setStatus("修复完成：检查 \(summary.checkedCorpora) 条语料，隔离 \(summary.quarantinedCorpora) 条。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func restoreSelectedRecycleEntry(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let entry = library.selectedRecycleEntry else { return }
        try await repository.restoreRecycleEntry(recycleEntryId: entry.recycleEntryId)
        library.setStatus("已恢复“\(entry.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func purgeSelectedRecycleEntry(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        guard let entry = library.selectedRecycleEntry else { return }
        let confirmed = await dialogService.confirm(
            title: "彻底删除回收站项目",
            message: "“\(entry.name)”将被永久移除。",
            confirmTitle: "彻底删除"
        )
        guard confirmed else { return }
        try await repository.purgeRecycleEntry(recycleEntryId: entry.recycleEntryId)
        library.setStatus("已永久删除“\(entry.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }
}
