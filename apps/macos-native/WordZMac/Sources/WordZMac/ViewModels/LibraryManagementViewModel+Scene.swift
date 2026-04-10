import Foundation

@MainActor
extension LibraryManagementViewModel {
    func syncScene() {
        let corporaByFolderID = Dictionary(grouping: librarySnapshot.corpora, by: \.folderId)
        let corporaByID = Dictionary(uniqueKeysWithValues: librarySnapshot.corpora.map { ($0.id, $0) })
        let visibleCorpora = filteredCorpora
        let folders = librarySnapshot.folders.map { folder in
            let corpusCount = corporaByFolderID[folder.id]?.count ?? 0
            return LibraryManagementFolderSceneItem(
                id: folder.id,
                title: folder.name,
                subtitle: "\(corpusCount) 条语料",
                isSelected: folder.id == selectedFolderID
            )
        }
        let corpusSets = librarySnapshot.corpusSets.map { corpusSet in
            let resolvedCorpora = corpusSet.corpusIDs.compactMap { corporaByID[$0] }
            let currentVisibleCount = resolvedCorpora.filter { corpus in
                let folderMatches = selectedFolderID == nil || corpus.folderId == selectedFolderID
                let metadataMatches = metadataFilterState.isEmpty || metadataFilterState.matches(corpus.metadata)
                return folderMatches && metadataMatches
            }.count
            return LibraryManagementCorpusSetSceneItem(
                id: corpusSet.id,
                title: corpusSet.name,
                subtitle: currentVisibleCount == resolvedCorpora.count
                    ? "\(resolvedCorpora.count) 条语料"
                    : "\(currentVisibleCount) / \(resolvedCorpora.count) 条语料",
                corpusCountText: "\(resolvedCorpora.count)",
                filterSummary: corpusSet.metadataFilterState.summaryText(in: WordZLocalization.shared.effectiveMode) ?? "无元数据筛选",
                isSelected: corpusSet.id == selectedCorpusSetID
            )
        }
        let corpora = visibleCorpora.map {
            LibraryManagementCorpusSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: $0.folderName,
                sourceType: $0.sourceType,
                metadataSummary: $0.metadata.compactSummary(in: WordZLocalization.shared.effectiveMode),
                isSelected: selectedCorpusIDs.contains($0.id),
                hasMissingYear: $0.metadata.yearLabel.isEmpty,
                hasMissingGenre: $0.metadata.genreLabel.isEmpty,
                hasMissingTags: $0.metadata.tags.isEmpty
            )
        }
        let recycleEntries = recycleSnapshot.entries.map {
            LibraryManagementRecycleSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: $0.originalFolderName.isEmpty ? $0.deletedAt : "\($0.originalFolderName) · \($0.deletedAt)",
                typeLabel: $0.type
            )
        }
        let librarySummary = selectedFolder == nil
            ? "文件夹 \(librarySnapshot.folders.count) · 语料 \(librarySnapshot.corpora.count)"
            : "文件夹 \(librarySnapshot.folders.count) · 当前目录 \(visibleCorpora.count) 条语料"
        let recycleSummary = "回收站 \(recycleSnapshot.totalCount) 项"
        let integritySummary = LibraryIntegritySummarySceneModel(
            visibleCorpusCount: visibleCorpora.count,
            missingYearCount: visibleCorpora.filter { $0.metadata.yearLabel.isEmpty }.count,
            missingGenreCount: visibleCorpora.filter { $0.metadata.genreLabel.isEmpty }.count,
            missingTagsCount: visibleCorpora.filter { $0.metadata.tags.isEmpty }.count
        )
        let metadataFilterSummary: String? = {
            guard !metadataFilterState.isEmpty else { return nil }
            return "筛选后 \(visibleCorpora.count) 条语料"
        }()
        let importProgress = importProgressSnapshot?.progress

        scene = LibraryManagementSceneModel(
            librarySummary: librarySummary,
            recycleSummary: recycleSummary,
            statusMessage: statusMessage.isEmpty
                ? (isBusy ? "正在处理语料库操作…" : "语料库管理已就绪")
                : statusMessage,
            preserveHierarchy: preserveHierarchy,
            metadataFilterSummary: metadataFilterSummary,
            integritySummary: integritySummary,
            importProgress: importProgress,
            importDetail: importProgressSnapshot.map(importDetailText),
            corpusSetsSummary: "语料集 \(librarySnapshot.corpusSets.count) 项",
            folders: folders,
            corpusSets: corpusSets,
            corpora: corpora,
            recycleEntries: recycleEntries,
            selectedCorpusSetID: selectedCorpusSetID,
            selectedFolderID: selectedFolderID,
            selectedCorpusID: selectedCorpusID,
            selectedCorpusIDs: selectedCorpusIDs,
            selectedRecycleEntryID: selectedRecycleEntryID,
            inspector: buildInspector(
                visibleCorpora: visibleCorpora,
                corporaByFolderID: corporaByFolderID,
                corporaByID: corporaByID
            )
        )
    }

    private func buildInspector(
        visibleCorpora: [LibraryCorpusItem],
        corporaByFolderID: [String: [LibraryCorpusItem]],
        corporaByID: [String: LibraryCorpusItem]
    ) -> LibraryManagementInspectorSceneModel {
        if let selectedCorpusSet {
            let resolvedCorpora = selectedCorpusSet.corpusIDs.compactMap { corporaByID[$0] }
            return LibraryManagementInspectorSceneModel(
                title: selectedCorpusSet.name,
                subtitle: "命名语料集",
                details: [
                    .init(id: "set-count", title: "语料数量", value: "\(resolvedCorpora.count)"),
                    .init(id: "set-filters", title: "元数据筛选", value: selectedCorpusSet.metadataFilterState.summaryText(in: WordZLocalization.shared.effectiveMode) ?? "无"),
                    .init(id: "set-updated", title: "最近更新", value: selectedCorpusSet.updatedAt.isEmpty ? "—" : selectedCorpusSet.updatedAt)
                ],
                actions: [
                    .init(id: "save-set", title: "更新当前语料集", role: .primary, action: .saveCurrentCorpusSet),
                    .init(id: "delete-set", title: "删除语料集", role: .destructive, action: .deleteSelectedCorpusSet)
                ]
            )
        }

        if selectedCorpusIDs.count > 1 {
            let currentSelection = self.selectedCorpora
            let missingYearCount = currentSelection.filter { $0.metadata.yearLabel.isEmpty }.count
            let missingGenreCount = currentSelection.filter { $0.metadata.genreLabel.isEmpty }.count
            let missingTagsCount = currentSelection.filter { $0.metadata.tags.isEmpty }.count
            return LibraryManagementInspectorSceneModel(
                title: "已选择 \(selectedCorpusIDs.count) 条语料",
                subtitle: "批量元数据操作",
                details: [
                    .init(id: "batch-count", title: "选中数量", value: "\(selectedCorpusIDs.count)"),
                    .init(id: "batch-scope", title: "当前视图", value: selectedFolder?.name ?? "全部语料"),
                    .init(id: "missing-year", title: "缺年份", value: "\(missingYearCount)"),
                    .init(id: "missing-genre", title: "缺体裁", value: "\(missingGenreCount)"),
                    .init(id: "missing-tags", title: "缺标签", value: "\(missingTagsCount)")
                ],
                actions: [
                    .init(id: "batch-edit-metadata", title: "批量编辑元数据", role: .primary, action: .editSelectedCorporaMetadata)
                ]
            )
        }

        if let selectedCorpus {
            return LibraryManagementInspectorSceneModel(
                title: selectedCorpus.name,
                subtitle: "语料 · \(selectedCorpus.sourceType.uppercased())",
                details: [
                    .init(id: "folder", title: "文件夹", value: selectedCorpus.folderName),
                    .init(id: "source", title: "来源类型", value: selectedCorpus.sourceType),
                    .init(id: "source-label", title: "来源", value: selectedCorpus.metadata.sourceLabel.isEmpty ? "—" : selectedCorpus.metadata.sourceLabel),
                    .init(id: "year-label", title: "年份", value: selectedCorpus.metadata.yearLabel.isEmpty ? "—" : selectedCorpus.metadata.yearLabel),
                    .init(id: "genre-label", title: "体裁", value: selectedCorpus.metadata.genreLabel.isEmpty ? "—" : selectedCorpus.metadata.genreLabel),
                    .init(id: "tags", title: "标签", value: selectedCorpus.metadata.tagsText.isEmpty ? "—" : selectedCorpus.metadata.tagsText),
                    .init(id: "scope", title: "当前视图", value: selectedFolder?.name ?? "全部语料")
                ],
                actions: [
                    .init(id: "open", title: "打开语料", role: .primary, action: .openSelectedCorpus),
                    .init(id: "preview", title: "快速预览", role: .normal, action: .quickLookSelectedCorpus),
                    .init(id: "info", title: "语料信息", role: .normal, action: .showSelectedCorpusInfo),
                    .init(id: "edit-metadata", title: "编辑元数据", role: .normal, action: .editSelectedCorpusMetadata),
                    .init(id: "rename-corpus", title: "重命名", role: .normal, action: .renameSelectedCorpus),
                    .init(id: "move-corpus", title: "移动到所选文件夹", role: .normal, action: .moveSelectedCorpusToSelectedFolder),
                    .init(id: "delete-corpus", title: "删除", role: .destructive, action: .deleteSelectedCorpus)
                ]
            )
        }

        if let selectedRecycleEntry {
            return LibraryManagementInspectorSceneModel(
                title: selectedRecycleEntry.name,
                subtitle: "回收站项目 · \(selectedRecycleEntry.type)",
                details: [
                    .init(id: "deleted-at", title: "删除时间", value: selectedRecycleEntry.deletedAt),
                    .init(id: "origin-folder", title: "原始文件夹", value: selectedRecycleEntry.originalFolderName),
                    .init(id: "item-count", title: "项目数量", value: "\(selectedRecycleEntry.itemCount)")
                ],
                actions: [
                    .init(id: "restore-recycle", title: "恢复项目", role: .primary, action: .restoreSelectedRecycleEntry),
                    .init(id: "purge-recycle", title: "彻底删除", role: .destructive, action: .purgeSelectedRecycleEntry)
                ]
            )
        }

        if let selectedFolder {
            let folderCorpora = corporaByFolderID[selectedFolder.id] ?? []
            return LibraryManagementInspectorSceneModel(
                title: selectedFolder.name,
                subtitle: "文件夹",
                details: [
                    .init(id: "folder-corpus-count", title: "语料数量", value: "\(folderCorpora.count)"),
                    .init(id: "visible-count", title: "当前视图", value: "\(visibleCorpora.count) 条语料"),
                    .init(id: "preserve-hierarchy", title: "导入保留层级", value: preserveHierarchy ? "开启" : "关闭")
                ],
                actions: [
                    .init(id: "import-folder", title: "导入到此文件夹", role: .primary, action: .importPaths),
                    .init(id: "rename-folder", title: "重命名文件夹", role: .normal, action: .renameSelectedFolder),
                    .init(id: "delete-folder", title: "删除文件夹", role: .destructive, action: .deleteSelectedFolder)
                ]
            )
        }

        return LibraryManagementInspectorSceneModel(
            title: "全部语料",
            subtitle: "选择一个文件夹、语料或回收站项目可查看详情。",
            details: [
                .init(id: "folder-total", title: "文件夹数量", value: "\(librarySnapshot.folders.count)"),
                .init(id: "corpus-total", title: "语料数量", value: "\(librarySnapshot.corpora.count)"),
                .init(id: "recycle-total", title: "回收站项目", value: "\(recycleSnapshot.totalCount)")
            ],
            actions: [
                .init(id: "import-root", title: "导入语料", role: .primary, action: .importPaths),
                .init(id: "create-folder-root", title: "新建文件夹", role: .normal, action: .createFolder),
                .init(id: "repair-library-root", title: "修复语料库", role: .normal, action: .repairLibrary)
            ]
        )
    }

    private func importDetailText(_ snapshot: LibraryImportProgressSnapshot) -> String {
        switch snapshot.phase {
        case .preparing:
            return "正在准备导入…"
        case .importing:
            let name = snapshot.currentName.isEmpty ? "当前文件" : snapshot.currentName
            return "正在导入 \(name) · \(snapshot.completedCount) / \(snapshot.totalCount)"
        case .committing:
            return "正在写入语料库索引…"
        case .completed:
            return "导入完成"
        }
    }
}
