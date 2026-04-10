import Foundation

extension LibraryManagementCoordinator {
    func renameSelectedCorpus(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        guard let newName = await dialogService.promptText(
            title: "重命名语料",
            message: "输入“\(selectedCorpus.name)”的新名称。",
            defaultValue: selectedCorpus.name,
            confirmTitle: "重命名",
            preferredRoute: preferredRoute
        ) else { return }
        let updated = try await repository.renameCorpus(corpusId: selectedCorpus.id, newName: newName)
        sidebar.selectedCorpusID = updated.id
        library.setStatus("已重命名语料为“\(updated.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func updateSelectedCorpusMetadata(
        _ metadata: CorpusMetadataProfile,
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        let updated = try await repository.updateCorpusMetadata(corpusId: selectedCorpus.id, metadata: metadata)
        sidebar.selectedCorpusID = updated.id
        library.dismissMetadataEditor()
        library.setStatus("已更新“\(updated.name)”的语料元数据。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
        if library.corpusInfoSheet?.id == updated.id {
            let summary = try await repository.loadCorpusInfo(corpusId: updated.id)
            library.presentCorpusInfo(
                LibraryCorpusInfoSceneModel(
                    id: summary.corpusId,
                    title: summary.title,
                    subtitle: "语料信息",
                    folderName: summary.folderName,
                    sourceType: summary.sourceType,
                    sourceLabelText: summary.metadata.sourceLabel.isEmpty ? "—" : summary.metadata.sourceLabel,
                    yearText: summary.metadata.yearLabel.isEmpty ? "—" : summary.metadata.yearLabel,
                    genreText: summary.metadata.genreLabel.isEmpty ? "—" : summary.metadata.genreLabel,
                    tagsText: summary.metadata.tagsText.isEmpty ? "—" : summary.metadata.tagsText,
                    importedAtText: summary.importedAt.isEmpty ? "—" : summary.importedAt,
                    encodingText: summary.detectedEncoding.isEmpty ? "—" : summary.detectedEncoding,
                    tokenCountText: "\(summary.tokenCount)",
                    typeCountText: "\(summary.typeCount)",
                    sentenceCountText: "\(summary.sentenceCount)",
                    paragraphCountText: "\(summary.paragraphCount)",
                    characterCountText: "\(summary.characterCount)",
                    ttrText: String(format: "%.4f", summary.ttr),
                    sttrText: summary.sttr > 0 ? String(format: "%.4f", summary.sttr) : "—",
                    representedPath: summary.representedPath
                )
            )
        }
    }

    func updateSelectedCorporaMetadata(
        _ patch: BatchCorpusMetadataPatch,
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

        library.dismissMetadataEditor()
        library.setStatus("已批量更新 \(targetCorpora.count) 条语料的元数据。")
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
        library.setStatus("已移动语料“\(selectedCorpus.name)”。")
        try await refreshLibraryState(into: library, sidebar: sidebar)
    }

    func deleteSelectedCorpus(
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws {
        guard let selectedCorpus = library.selectedCorpus ?? sidebar.selectedCorpus else { return }
        let confirmed = await dialogService.confirm(
            title: "删除语料",
            message: "“\(selectedCorpus.name)”会被移到回收站。",
            confirmTitle: "删除",
            preferredRoute: preferredRoute
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
}
