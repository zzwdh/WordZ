import Foundation

struct TaskCenterWindowSection: Identifiable, Equatable {
    let state: NativeBackgroundTaskState
    let title: String
    let itemCountSummary: String
    let items: [NativeBackgroundTaskItem]

    var id: NativeBackgroundTaskState {
        state
    }
}

struct TaskCenterWindowSceneModel: Equatable {
    let totalCount: Int
    let matchedCount: Int
    let runningCount: Int
    let completedCount: Int
    let failedCount: Int
    let subtitle: String
    let sections: [TaskCenterWindowSection]
    let aggregateProgress: Double?
    let aggregateProgressSummary: String
    let showsAggregateProgress: Bool
    let hasFinishedItems: Bool
    let isSearching: Bool

    init(
        taskCenterScene: NativeTaskCenterSceneModel,
        searchQuery: String,
        languageMode: AppLanguageMode
    ) {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortedItems = taskCenterScene.items.sorted { $0.updatedAt > $1.updatedAt }
        let filteredItems = trimmedQuery.isEmpty
            ? sortedItems
            : sortedItems.filter { item in
                Self.matchesSearchQuery(
                    trimmedQuery,
                    item: item,
                    languageMode: languageMode
                )
            }

        self.totalCount = taskCenterScene.items.count
        self.matchedCount = filteredItems.count
        self.runningCount = taskCenterScene.runningCount
        self.completedCount = taskCenterScene.completedCount
        self.failedCount = taskCenterScene.failedCount
        self.aggregateProgress = taskCenterScene.aggregateProgress
        self.showsAggregateProgress = taskCenterScene.runningCount > 0 && taskCenterScene.aggregateProgress != nil
        self.hasFinishedItems = taskCenterScene.completedCount > 0 || taskCenterScene.failedCount > 0
        self.isSearching = !trimmedQuery.isEmpty
        self.subtitle = Self.makeSubtitle(
            baseSummary: taskCenterScene.summary,
            totalCount: taskCenterScene.items.count,
            matchedCount: filteredItems.count,
            runningCount: taskCenterScene.runningCount,
            isSearching: !trimmedQuery.isEmpty,
            languageMode: languageMode
        )
        self.aggregateProgressSummary = Self.makeAggregateProgressSummary(
            runningCount: taskCenterScene.runningCount,
            aggregateProgress: taskCenterScene.aggregateProgress,
            languageMode: languageMode
        )
        self.sections = Self.makeSections(
            items: filteredItems,
            languageMode: languageMode
        )
    }

    var isEmpty: Bool {
        totalCount == 0
    }

    var showsSearchEmptyState: Bool {
        !isEmpty && matchedCount == 0
    }

    private static func makeSubtitle(
        baseSummary: String,
        totalCount: Int,
        matchedCount: Int,
        runningCount: Int,
        isSearching: Bool,
        languageMode: AppLanguageMode
    ) -> String {
        guard isSearching, totalCount > 0 else { return baseSummary }
        return String(
            format: wordZText(
                "匹配 %d / 总计 %d · 运行中 %d",
                "Showing %d of %d · %d running",
                mode: languageMode
            ),
            matchedCount,
            totalCount,
            runningCount
        )
    }

    private static func makeAggregateProgressSummary(
        runningCount: Int,
        aggregateProgress: Double?,
        languageMode: AppLanguageMode
    ) -> String {
        guard runningCount > 0 else {
            return wordZText("当前没有运行中的任务", "No tasks running", mode: languageMode)
        }
        guard let aggregateProgress else {
            return String(
                format: wordZText("%d 个进行中", "%d running", mode: languageMode),
                runningCount
            )
        }
        return String(
            format: wordZText(
                "%d 个进行中 · %d%%",
                "%d running · %d%%",
                mode: languageMode
            ),
            runningCount,
            Int((aggregateProgress * 100).rounded())
        )
    }

    private static func makeSections(
        items: [NativeBackgroundTaskItem],
        languageMode: AppLanguageMode
    ) -> [TaskCenterWindowSection] {
        let groupedItems = Dictionary(grouping: items, by: \.state)
        return orderedStates.compactMap { state in
            guard let sectionItems = groupedItems[state], !sectionItems.isEmpty else { return nil }
            return TaskCenterWindowSection(
                state: state,
                title: state.displayLabel(in: languageMode),
                itemCountSummary: String(
                    format: wordZText("%d 项", "%d items", mode: languageMode),
                    sectionItems.count
                ),
                items: sectionItems.sorted { $0.updatedAt > $1.updatedAt }
            )
        }
    }

    private static func matchesSearchQuery(
        _ query: String,
        item: NativeBackgroundTaskItem,
        languageMode: AppLanguageMode
    ) -> Bool {
        let searchableFields = [
            item.title,
            item.detail,
            item.state.displayLabel(in: languageMode),
            item.primaryAction?.title(in: languageMode) ?? ""
        ]
        return searchableFields.contains { field in
            field.localizedCaseInsensitiveContains(query)
        }
    }

    private static let orderedStates: [NativeBackgroundTaskState] = [
        .running,
        .failed,
        .completed
    ]
}
