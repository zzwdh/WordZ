import Foundation

@MainActor
extension LibraryManagementViewModel {
    func syncScene() {
        let languageMode = WordZLocalization.shared.effectiveMode
        let corporaByFolderID = Dictionary(grouping: librarySnapshot.corpora, by: \.folderId)
        let corporaByID = Dictionary(uniqueKeysWithValues: librarySnapshot.corpora.map { ($0.id, $0) })
        let visibleCorpora = filteredCorpora
        let recentCorpusSetIDSet = Set(recentCorpusSetIDs)
        let navigationSelection = buildNavigationSelection(recentCorpusSetIDSet: recentCorpusSetIDSet)

        let folders = librarySnapshot.folders
            .filter { folder in
                matchesSearchQuery(folder) || folder.id == selectedFolderID
            }
            .map { folder in
            let corpusCount = corporaByFolderID[folder.id]?.count ?? 0
            return LibraryManagementFolderSceneItem(
                id: folder.id,
                title: folder.name,
                subtitle: "\(corpusCount) 条语料",
                isSelected: folder.id == selectedFolderID
            )
        }

        let allCorpusSets = librarySnapshot.corpusSets
            .filter { corpusSet in
                matchesSearchQuery(corpusSet, corporaByID: corporaByID) || corpusSet.id == selectedCorpusSetID
            }
            .map { corpusSet in
            let resolvedCorpora = corpusSet.corpusIDs.compactMap { corporaByID[$0] }
            let currentVisibleCount = resolvedCorpora.filter { corpus in
                let folderMatches = selectedFolderID == nil || corpus.folderId == selectedFolderID
                let metadataMatches = metadataFilterState.isEmpty || metadataFilterState.matches(corpus.metadata)
                let searchMatches = matchesSearchQuery(corpus)
                return folderMatches && metadataMatches && searchMatches
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

        let recentCorpusSetItems = recentCorpusSets.compactMap { recentSet in
            allCorpusSets.first(where: { $0.id == recentSet.id })
        }
        let corpusSets = allCorpusSets.filter { !recentCorpusSetIDSet.contains($0.id) }
        let selectedCorpusSetSceneItem = allCorpusSets.first(where: { $0.id == selectedCorpusSetID })

        let corpora: [LibraryManagementCorpusSceneItem] = visibleCorpora.map { corpus in
            let cleaningSummary = corpus.cleaningSummary
            return LibraryManagementCorpusSceneItem(
                id: corpus.id,
                title: corpus.name,
                subtitle: corpus.folderName,
                sourceType: corpus.sourceType,
                metadataSummary: corpus.metadata.compactSummary(in: languageMode),
                cleaningStatus: corpus.cleaningStatus,
                cleaningStatusTitle: corpus.cleaningStatus.title(in: languageMode),
                cleaningSummary: cleaningSummary?.ruleHitsSummary(in: languageMode, limit: 2)
                    ?? wordZText("尚未执行自动清洗", "Auto-cleaning not run yet", mode: languageMode),
                isSelected: selectedCorpusIDs.contains(corpus.id),
                hasMissingYear: corpus.metadata.yearLabel.isEmpty,
                hasMissingGenre: corpus.metadata.genreLabel.isEmpty,
                hasMissingTags: corpus.metadata.tags.isEmpty
            )
        }

        let recycleEntries = recycleSnapshot.entries
            .filter { matchesSearchQuery($0) }
            .map {
            LibraryManagementRecycleSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: $0.originalFolderName.isEmpty ? $0.deletedAt : "\($0.originalFolderName) · \($0.deletedAt)",
                typeLabel: $0.type
            )
        }

        let librarySummary = hasSearchQuery
            ? "文件夹 \(librarySnapshot.folders.count) · 语料 \(librarySnapshot.corpora.count) · 搜索 “\(normalizedSearchQuery)”"
            : "文件夹 \(librarySnapshot.folders.count) · 语料 \(librarySnapshot.corpora.count)"
        let recycleSummary = "回收站 \(recycleSnapshot.totalCount) 项"
        let autoCleaningSummary = LibraryAutoCleaningSummarySceneModel(
            cleanedCount: visibleCorpora.filter { $0.cleaningStatus == .cleaned }.count,
            pendingCount: visibleCorpora.filter { $0.cleaningStatus == .pending }.count,
            changedCount: visibleCorpora.filter { $0.cleaningStatus == .cleanedWithChanges }.count
        )
        let integritySummary = LibraryIntegritySummarySceneModel(
            visibleCorpusCount: visibleCorpora.count,
            missingYearCount: visibleCorpora.filter { $0.metadata.yearLabel.isEmpty }.count,
            missingGenreCount: visibleCorpora.filter { $0.metadata.genreLabel.isEmpty }.count,
            missingTagsCount: visibleCorpora.filter { $0.metadata.tags.isEmpty }.count
        )
        let metadataFilterSummary = metadataFilterState.summaryText(in: WordZLocalization.shared.effectiveMode)
        let importProgress = importProgressSnapshot?.progress

        scene = LibraryManagementSceneModel(
            librarySummary: librarySummary,
            currentScopeSummary: buildCurrentScopeSummary(
                visibleCorpora: visibleCorpora,
                navigationSelection: navigationSelection
            ),
            recycleSummary: recycleSummary,
            statusMessage: statusMessage.isEmpty
                ? (isBusy ? "正在处理语料库操作…" : "语料库管理已就绪")
                : statusMessage,
            preserveHierarchy: preserveHierarchy,
            metadataFilterSummary: metadataFilterSummary,
            autoCleaningSummary: autoCleaningSummary,
            integritySummary: integritySummary,
            importProgress: importProgress,
            importDetail: importProgressSnapshot.map(importDetailText),
            navigationSelection: navigationSelection,
            content: buildContentScene(
                navigationSelection: navigationSelection,
                visibleCorpora: visibleCorpora,
                recycleEntries: recycleEntries,
                selectedCorpusSetSceneItem: selectedCorpusSetSceneItem,
                hasSearchQuery: hasSearchQuery
            ),
            filterChips: buildFilterChips(
                searchQuery: normalizedSearchQuery,
                metadataFilterSummary: metadataFilterSummary,
                integritySummary: integritySummary
            ),
            overflowActions: buildOverflowActions(),
            recentCorpusSetsSummary: "最近使用 \(recentCorpusSetItems.count) 项",
            corpusSetsSummary: "语料集 \(librarySnapshot.corpusSets.count) 项",
            folders: folders,
            recentCorpusSets: recentCorpusSetItems,
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

    private func buildNavigationSelection(recentCorpusSetIDSet: Set<String>) -> LibraryManagementNavigationSelection {
        if showsRecycleBin {
            return .recycleBin
        }
        if let selectedCorpusSetID {
            return recentCorpusSetIDSet.contains(selectedCorpusSetID)
                ? .recentCorpusSet(selectedCorpusSetID)
                : .savedCorpusSet(selectedCorpusSetID)
        }
        if let selectedFolderID {
            return .folder(selectedFolderID)
        }
        return .allCorpora
    }

    private func buildCurrentScopeSummary(
        visibleCorpora: [LibraryCorpusItem],
        navigationSelection: LibraryManagementNavigationSelection
    ) -> String {
        let searchSuffix = hasSearchQuery ? " · 搜索 “\(normalizedSearchQuery)”" : ""
        switch navigationSelection {
        case .recycleBin:
            return "查看回收站 \(recycleSnapshot.totalCount) 项" + searchSuffix
        case .savedCorpusSet, .recentCorpusSet:
            if let selectedCorpusSet {
                return "\(selectedCorpusSet.name) · \(visibleCorpora.count) 条语料" + searchSuffix
            }
        case .folder:
            if let selectedFolder {
                return "\(selectedFolder.name) · \(visibleCorpora.count) 条语料" + searchSuffix
            }
        case .allCorpora:
            break
        }

        if selectedCorpusIDs.count > 1 {
            return "已选择 \(selectedCorpusIDs.count) 条语料" + searchSuffix
        }
        return "全部语料 · \(visibleCorpora.count) 条语料" + searchSuffix
    }

    private func buildContentScene(
        navigationSelection: LibraryManagementNavigationSelection,
        visibleCorpora: [LibraryCorpusItem],
        recycleEntries: [LibraryManagementRecycleSceneItem],
        selectedCorpusSetSceneItem: LibraryManagementCorpusSetSceneItem?,
        hasSearchQuery: Bool
    ) -> LibraryManagementContentSceneModel {
        switch navigationSelection {
        case .recycleBin:
            return LibraryManagementContentSceneModel(
                mode: .recycleBin,
                title: "回收站",
                subtitle: "当前共有 \(recycleEntries.count) 项",
                emptyTitle: hasSearchQuery ? "没有匹配的回收站项目" : "回收站为空",
                emptyDescription: hasSearchQuery
                    ? "调整搜索词后，可继续查找已删除的文件夹或语料。"
                    : "已删除的文件夹和语料会先进入这里，便于恢复或彻底删除。"
            )
        case .savedCorpusSet, .recentCorpusSet:
            return LibraryManagementContentSceneModel(
                mode: .corpora,
                title: selectedCorpusSet?.name ?? "命名语料集",
                subtitle: selectedCorpusSetSceneItem?.subtitle ?? "\(visibleCorpora.count) 条语料",
                emptyTitle: hasSearchQuery ? "当前搜索没有匹配语料" : "当前语料集没有可见语料",
                emptyDescription: hasSearchQuery
                    ? "可以调整搜索词，或清除筛选条件后再查看结果。"
                    : "可以调整筛选条件，或者切换到其他文件夹和语料集。"
            )
        case .folder:
            return LibraryManagementContentSceneModel(
                mode: .corpora,
                title: selectedFolder?.name ?? "文件夹",
                subtitle: "\(visibleCorpora.count) 条语料",
                emptyTitle: hasSearchQuery ? "当前搜索没有匹配语料" : "当前视图没有语料",
                emptyDescription: hasSearchQuery
                    ? "可以调整搜索词，或切换到其他文件夹继续查找。"
                    : "可以切换到“全部语料”，或者直接导入新语料。"
            )
        case .allCorpora:
            return LibraryManagementContentSceneModel(
                mode: .corpora,
                title: "全部语料",
                subtitle: "共 \(visibleCorpora.count) 条语料",
                emptyTitle: hasSearchQuery ? "当前搜索没有匹配语料" : "当前视图没有语料",
                emptyDescription: hasSearchQuery
                    ? "可以调整搜索词，或直接导入新语料。"
                    : "可以切换到“全部语料”，或者直接导入新语料。"
            )
        }
    }

    private func buildFilterChips(
        searchQuery: String,
        metadataFilterSummary: String?,
        integritySummary: LibraryIntegritySummarySceneModel
    ) -> [LibraryManagementFilterChipSceneItem] {
        var chips: [LibraryManagementFilterChipSceneItem] = []

        if !searchQuery.isEmpty {
            chips.append(
                LibraryManagementFilterChipSceneItem(
                    id: "search-query",
                    title: "搜索：\(searchQuery)",
                    systemImage: "magnifyingglass"
                )
            )
        }

        if let metadataFilterSummary, !metadataFilterSummary.isEmpty {
            chips.append(
                LibraryManagementFilterChipSceneItem(
                    id: "metadata-filter-summary",
                    title: metadataFilterSummary,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            )
        }
        if integritySummary.missingYearCount > 0 {
            chips.append(
                .init(
                    id: "missing-year",
                    title: "缺年份 \(integritySummary.missingYearCount)",
                    systemImage: "calendar.badge.exclamationmark"
                )
            )
        }
        if integritySummary.missingGenreCount > 0 {
            chips.append(
                .init(
                    id: "missing-genre",
                    title: "缺体裁 \(integritySummary.missingGenreCount)",
                    systemImage: "text.book.closed"
                )
            )
        }
        if integritySummary.missingTagsCount > 0 {
            chips.append(
                .init(
                    id: "missing-tags",
                    title: "缺标签 \(integritySummary.missingTagsCount)",
                    systemImage: "tag.slash"
                )
            )
        }

        return chips
    }

    private func buildOverflowActions() -> [LibraryManagementOverflowActionSceneItem] {
        [
            .init(id: "refresh", title: "刷新", action: .refresh),
            .init(id: "create-folder", title: "新建文件夹", action: .createFolder),
            .init(id: "backup-library", title: "备份", action: .backupLibrary),
            .init(id: "restore-library", title: "恢复", action: .restoreLibrary),
            .init(id: "repair-library", title: "修复", action: .repairLibrary)
        ]
    }

    private func buildInspector(
        visibleCorpora: [LibraryCorpusItem],
        corporaByFolderID: [String: [LibraryCorpusItem]],
        corporaByID: [String: LibraryCorpusItem]
    ) -> LibraryManagementInspectorSceneModel? {
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
            let currentSelection = selectedCorpora
            let languageMode = WordZLocalization.shared.effectiveMode
            let missingYearCount = currentSelection.filter { $0.metadata.yearLabel.isEmpty }.count
            let missingGenreCount = currentSelection.filter { $0.metadata.genreLabel.isEmpty }.count
            let missingTagsCount = currentSelection.filter { $0.metadata.tags.isEmpty }.count
            return LibraryManagementInspectorSceneModel(
                title: "已选择 \(selectedCorpusIDs.count) 条语料",
                subtitle: "批量操作",
                details: [
                    .init(id: "batch-count", title: "选中数量", value: "\(selectedCorpusIDs.count)"),
                    .init(id: "batch-scope", title: "当前视图", value: currentScopeSummaryForInspector()),
                    .init(id: "batch-pending-cleaning", title: "待清洗", value: "\(currentSelection.filter { $0.cleaningStatus == .pending }.count)"),
                    .init(id: "batch-cleaning-changed", title: "清洗有变更", value: "\(currentSelection.filter { $0.cleaningStatus == .cleanedWithChanges }.count)"),
                    .init(
                        id: "batch-cleaning-hits",
                        title: "规则命中",
                        value: aggregateCleaningHitsSummary(
                            currentSelection.compactMap(\.cleaningSummary),
                            languageMode: languageMode
                        )
                    ),
                    .init(id: "missing-year", title: "缺年份", value: "\(missingYearCount)"),
                    .init(id: "missing-genre", title: "缺体裁", value: "\(missingGenreCount)"),
                    .init(id: "missing-tags", title: "缺标签", value: "\(missingTagsCount)")
                ],
                actions: [
                    .init(id: "batch-clean-metadata", title: "批量清洗所选语料", role: .primary, action: .cleanSelectedCorpora),
                    .init(id: "batch-edit-metadata", title: "批量编辑元数据", role: .primary, action: .editSelectedCorporaMetadata)
                ]
            )
        }

        if let selectedCorpus {
            let languageMode = WordZLocalization.shared.effectiveMode
            let cleaningSummary = selectedCorpus.cleaningSummary
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
                    .init(id: "scope", title: "当前视图", value: currentScopeSummaryForInspector()),
                    .init(id: "clean-status", title: "自动清洗", value: selectedCorpus.cleaningStatus.title(in: languageMode)),
                    .init(id: "cleaned-at", title: "最近清洗", value: cleaningSummary?.cleanedAt.isEmpty == false ? cleaningSummary?.cleanedAt ?? "—" : "—"),
                    .init(
                        id: "clean-char-counts",
                        title: "字符变化",
                        value: cleaningSummary.map {
                            "\($0.originalCharacterCount) -> \($0.cleanedCharacterCount)"
                        } ?? "—"
                    ),
                    .init(
                        id: "clean-rule-hits",
                        title: "规则命中",
                        value: cleaningSummary?.ruleHitsSummary(in: languageMode) ?? "—"
                    )
                ],
                actions: [
                    .init(id: "open", title: "打开语料", role: .primary, action: .openSelectedCorpus),
                    .init(id: "clean-corpus", title: "重新清洗", role: .primary, action: .cleanSelectedCorpus),
                    .init(id: "preview", title: "快速预览", role: .normal, action: .quickLookSelectedCorpus),
                    .init(id: "share", title: "分享语料", role: .normal, action: .shareSelectedCorpus),
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

        return nil
    }

    private func currentScopeSummaryForInspector() -> String {
        if let selectedCorpusSet {
            return selectedCorpusSet.name
        }
        if let selectedFolder {
            return selectedFolder.name
        }
        if showsRecycleBin {
            return "回收站"
        }
        return "全部语料"
    }

    func makeCorpusInfoScene(
        summary: CorpusInfoSummary,
        languageMode: AppLanguageMode = WordZLocalization.shared.effectiveMode
    ) -> LibraryCorpusInfoSceneModel {
        let cleaningSummary = summary.cleaningSummary
        return LibraryCorpusInfoSceneModel(
            id: summary.corpusId,
            title: summary.title,
            subtitle: wordZText("语料信息", "Corpus Info", mode: languageMode),
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
            representedPath: summary.representedPath,
            cleaningStatusTitle: summary.cleaningStatus.title(in: languageMode),
            cleanedAtText: cleaningSummary?.cleanedAt.isEmpty == false
                ? cleaningSummary?.cleanedAt ?? "—"
                : "—",
            originalCharacterCountText: cleaningSummary.map { "\($0.originalCharacterCount)" } ?? "—",
            cleanedCharacterCountText: cleaningSummary.map { "\($0.cleanedCharacterCount)" } ?? "—",
            cleaningRuleHitsText: cleaningSummary?.ruleHitsSummary(in: languageMode)
                ?? wordZText("尚未执行自动清洗", "Auto-cleaning not run yet", mode: languageMode)
        )
    }

    func makeImportSummaryScene(
        result: LibraryImportResult,
        languageMode: AppLanguageMode = WordZLocalization.shared.effectiveMode
    ) -> LibraryImportSummarySceneModel {
        LibraryImportSummarySceneModel(
            id: UUID().uuidString,
            title: wordZText("导入完成", "Import Completed", mode: languageMode),
            subtitle: wordZText("自动清洗摘要", "Auto-Cleaning Summary", mode: languageMode),
            importedCountText: "\(result.importedCount)",
            skippedCountText: "\(result.skippedCount)",
            cleanedCountText: "\(result.cleaningSummary.cleanedCount)",
            changedCountText: "\(result.cleaningSummary.changedCount)",
            ruleHitsSummaryText: result.cleaningSummary.ruleHits.isEmpty
                ? wordZText("未命中清洗规则", "No cleaning rules hit", mode: languageMode)
                : result.cleaningSummary.ruleHits.prefix(3)
                    .map { "\($0.title(in: languageMode)) \($0.count)" }
                    .joined(separator: " · "),
            firstFailureText: result.failureItems.first.map {
                "\($0.fileName) (\($0.reason))"
            } ?? wordZText("无", "None", mode: languageMode)
        )
    }

    private func aggregateCleaningHitsSummary(
        _ summaries: [LibraryCorpusCleaningReportSummary],
        languageMode: AppLanguageMode
    ) -> String {
        let merged = summaries
            .flatMap(\.ruleHits)
            .reduce(into: [String: Int]()) { partialResult, hit in
                partialResult[hit.id, default: 0] += hit.count
            }

        guard !merged.isEmpty else {
            return wordZText("无", "None", mode: languageMode)
        }

        return merged.keys.sorted().prefix(3).map { key in
            let hit = LibraryCorpusCleaningRuleHit(id: key, count: merged[key] ?? 0)
            return "\(hit.title(in: languageMode)) \(hit.count)"
        }
        .joined(separator: " · ")
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
