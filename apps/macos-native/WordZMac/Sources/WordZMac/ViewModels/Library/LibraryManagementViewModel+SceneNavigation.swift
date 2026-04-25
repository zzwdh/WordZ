import Foundation

@MainActor
extension LibraryManagementViewModel {
    func buildNavigationSelection(recentCorpusSetIDSet: Set<String>) -> LibraryManagementNavigationSelection {
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

    func buildCurrentScopeSummary(
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

    func buildContentScene(
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

    func currentScopeSummaryForInspector() -> String {
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
}
