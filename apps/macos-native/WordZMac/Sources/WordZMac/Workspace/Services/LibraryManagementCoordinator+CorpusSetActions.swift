import Foundation

extension LibraryManagementCoordinator {
    func saveCurrentCorpusSet(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let repository = repository as? any CorpusSetManagingRepository else {
            throw NSError(
                domain: "WordZMac.LibraryManagementCoordinator",
                code: 31,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持命名语料集。"]
            )
        }
        let targetCorpora = library.saveableCorpusSetMembers
        guard !targetCorpora.isEmpty else {
            throw NSError(
                domain: "WordZMac.LibraryManagementCoordinator",
                code: 32,
                userInfo: [NSLocalizedDescriptionKey: "当前没有可保存到语料集的语料。"]
            )
        }

        let defaultName: String
        if let existingSet = library.selectedCorpusSet {
            defaultName = existingSet.name
        } else if library.metadataFilterState.activeFilterCount > 0 {
            defaultName = "筛选语料集"
        } else if targetCorpora.count == 1 {
            defaultName = targetCorpora[0].name
        } else {
            defaultName = "命名语料集"
        }

        guard let name = await dialogService.promptText(
            title: "保存语料集",
            message: "为当前语料子集输入一个名称。",
            defaultValue: defaultName,
            confirmTitle: "保存",
            preferredRoute: preferredRoute
        ) else { return }

        let savedSet = try await repository.saveCorpusSet(
            name: name,
            corpusIDs: targetCorpora.map(\.id),
            metadataFilterState: library.metadataFilterState
        )
        try await refreshLibraryState(into: library, sidebar: sidebar)
        library.selectCorpusSet(savedSet.id)
        sidebar.applyCorpusSet(savedSet)
        library.setStatus("已保存语料集“\(savedSet.name)”。")
    }

    func deleteSelectedCorpusSet(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let repository = repository as? any CorpusSetManagingRepository else {
            throw NSError(
                domain: "WordZMac.LibraryManagementCoordinator",
                code: 33,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持命名语料集。"]
            )
        }
        guard let selectedSet = library.selectedCorpusSet else { return }
        let confirmed = await dialogService.confirm(
            title: "删除语料集",
            message: "“\(selectedSet.name)”将从已保存语料集中移除。",
            confirmTitle: "删除",
            preferredRoute: preferredRoute
        )
        guard confirmed else { return }
        try await repository.deleteCorpusSet(corpusSetID: selectedSet.id)
        try await refreshLibraryState(into: library, sidebar: sidebar)
        library.selectCorpusSet(nil)
        if sidebar.selectedCorpusSetID == selectedSet.id {
            sidebar.applyCorpusSet(nil)
        }
        library.setStatus("已删除语料集“\(selectedSet.name)”。")
    }
}
