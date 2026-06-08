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
        let corpusSceneMetrics = buildCorpusSceneMetrics(
            visibleCorpora: visibleCorpora,
            selectedCorpusIDs: selectedCorpusIDs,
            languageMode: languageMode
        )

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
                let visibleSetCorpora = corpusSet.corpusIDs.compactMap { corporaByID[$0] }
                let currentVisibleCount = visibleSetCorpora.filter { corpus in
                    matchesSearchQuery(corpus)
                }.count
                let totalCorpusCount = corpusSet.corpusIDs.count
                return LibraryManagementCorpusSetSceneItem(
                    id: corpusSet.id,
                    title: corpusSet.name,
                    subtitle: currentVisibleCount == totalCorpusCount
                        ? "\(totalCorpusCount) 条语料"
                        : "\(currentVisibleCount) / \(totalCorpusCount) 条语料",
                    isSmart: !corpusSet.metadataFilterState.isEmpty,
                    kindTitle: corpusSet.metadataFilterState.isEmpty ? "固定语料集" : "智能语料集",
                    snapshotSummary: corpusSet.metadataFilterState.isEmpty
                        ? "手动保存的语料快照"
                        : "按元数据筛选动态整理",
                    corpusCountText: "\(totalCorpusCount)",
                    filterSummary: corpusSet.metadataFilterState.summaryText(in: WordZLocalization.shared.effectiveMode) ?? "无元数据筛选",
                    isSelected: corpusSet.id == selectedCorpusSetID
                )
            }

        let recentCorpusSetItems = recentCorpusSets.compactMap { recentSet in
            allCorpusSets.first(where: { $0.id == recentSet.id })
        }
        let corpusSets = allCorpusSets.filter { !recentCorpusSetIDSet.contains($0.id) }
        let selectedCorpusSetSceneItem = allCorpusSets.first(where: { $0.id == selectedCorpusSetID })

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
            ? "DB \(librarySnapshot.corpora.count) · 文件夹 \(librarySnapshot.folders.count) · 搜索 “\(normalizedSearchQuery)”"
            : "DB \(librarySnapshot.corpora.count) · 文件夹 \(librarySnapshot.folders.count)"
        let recycleSummary = "回收站 \(recycleSnapshot.totalCount) 项"
        let metadataFilterSummary = metadataFilterState.summaryText(in: WordZLocalization.shared.effectiveMode)
        let importProgress = importProgressSnapshot?.progress

        let nextScene = LibraryManagementSceneModel(
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
            autoCleaningSummary: corpusSceneMetrics.autoCleaningSummary,
            integritySummary: corpusSceneMetrics.integritySummary,
            readinessSummary: corpusSceneMetrics.readinessSummary,
            metadataStudio: corpusSceneMetrics.metadataStudio,
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
                integritySummary: corpusSceneMetrics.integritySummary
            ),
            overflowActions: buildOverflowActions(),
            recentCorpusSetsSummary: "最近使用 \(recentCorpusSetItems.count) 项",
            corpusSetsSummary: "语料集 \(librarySnapshot.corpusSets.count) 项",
            folders: folders,
            recentCorpusSets: recentCorpusSetItems,
            corpusSets: corpusSets,
            corpora: corpusSceneMetrics.corpora,
            recycleEntries: recycleEntries,
            selectedCorpusSetID: selectedCorpusSetID,
            selectedFolderID: selectedFolderID,
            selectedCorpusID: selectedCorpusID,
            selectedCorpusIDs: selectedCorpusIDs,
            selectedRecycleEntryID: selectedRecycleEntryID,
            inspector: buildInspector(
                visibleCorpora: visibleCorpora,
                corporaByFolderID: corporaByFolderID,
                corporaByID: corporaByID,
                readinessByCorpusID: corpusSceneMetrics.readinessByCorpusID
            )
        )
        if scene != nextScene {
            scene = nextScene
        }
    }
}
