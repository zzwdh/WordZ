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
                userInfo: [NSLocalizedDescriptionKey: wordZText("当前仓储尚不支持命名语料集。", "The current repository does not support named corpus sets yet.", mode: .system)]
            )
        }
        let targetCorpora = library.saveableCorpusSetMembers
        guard !targetCorpora.isEmpty else {
            throw NSError(
                domain: "WordZMac.LibraryManagementCoordinator",
                code: 32,
                userInfo: [NSLocalizedDescriptionKey: wordZText("当前没有可保存到语料集的语料。", "There are no corpora available to save into a corpus set.", mode: .system)]
            )
        }

        let defaultName: String
        if let existingSet = library.selectedCorpusSet {
            defaultName = existingSet.name
        } else if library.metadataFilterState.activeFilterCount > 0 {
            defaultName = wordZText("筛选语料集", "Filtered Corpus Set", mode: .system)
        } else if targetCorpora.count == 1 {
            defaultName = targetCorpora[0].name
        } else {
            defaultName = wordZText("命名语料集", "Named Corpus Set", mode: .system)
        }

        guard let name = await dialogService.promptText(
            title: wordZText("保存语料集", "Save Corpus Set", mode: .system),
            message: wordZText("为当前语料子集输入一个名称。", "Enter a name for the current corpus subset.", mode: .system),
            defaultValue: defaultName,
            confirmTitle: wordZText("保存", "Save", mode: .system),
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
        library.setStatus(
            l10nFormat(
                "已保存语料集“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Saved corpus set \"%@\".",
                savedSet.name
            )
        )
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
                userInfo: [NSLocalizedDescriptionKey: wordZText("当前仓储尚不支持命名语料集。", "The current repository does not support named corpus sets yet.", mode: .system)]
            )
        }
        guard let selectedSet = library.selectedCorpusSet else { return }
        let confirmed = await dialogService.confirm(
            title: wordZText("删除语料集", "Delete Corpus Set", mode: .system),
            message: l10nFormat(
                "“%@”将从已保存语料集中移除。",
                table: "Errors",
                mode: .system,
                fallback: "\"%@\" will be removed from saved corpus sets.",
                selectedSet.name
            ),
            confirmTitle: wordZText("删除", "Delete", mode: .system),
            preferredRoute: preferredRoute
        )
        guard confirmed else { return }
        try await repository.deleteCorpusSet(corpusSetID: selectedSet.id)
        try await refreshLibraryState(into: library, sidebar: sidebar)
        library.selectCorpusSet(nil)
        if sidebar.selectedCorpusSetID == selectedSet.id {
            sidebar.applyCorpusSet(nil)
        }
        library.setStatus(
            l10nFormat(
                "已删除语料集“%@”。",
                table: "Errors",
                mode: .system,
                fallback: "Deleted corpus set \"%@\".",
                selectedSet.name
            )
        )
    }
}
