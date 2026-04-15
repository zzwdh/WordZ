import Foundation

struct LibraryManagementFolderSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
}

struct LibraryManagementCorpusSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let sourceType: String
    let metadataSummary: String
    let cleaningStatus: LibraryCorpusCleaningStatus
    let cleaningStatusTitle: String
    let cleaningSummary: String
    let isSelected: Bool
    let hasMissingYear: Bool
    let hasMissingGenre: Bool
    let hasMissingTags: Bool
}

struct LibraryManagementCorpusSetSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let corpusCountText: String
    let filterSummary: String
    let isSelected: Bool
}

struct LibraryManagementRecycleSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let typeLabel: String
}

enum LibraryManagementNavigationSelection: Hashable, Equatable {
    case allCorpora
    case folder(String)
    case savedCorpusSet(String)
    case recentCorpusSet(String)
    case recycleBin
}

enum LibraryManagementContentMode: Equatable {
    case corpora
    case recycleBin
}

struct LibraryManagementContentSceneModel: Equatable {
    let mode: LibraryManagementContentMode
    let title: String
    let subtitle: String
    let emptyTitle: String
    let emptyDescription: String
}

struct LibraryManagementFilterChipSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
}

struct LibraryManagementOverflowActionSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let action: LibraryManagementAction
}

enum LibraryManagementInspectorActionRole: Equatable {
    case primary
    case normal
    case destructive
}

struct LibraryManagementInspectorDetailItem: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct LibraryManagementInspectorActionItem: Identifiable, Equatable {
    let id: String
    let title: String
    let role: LibraryManagementInspectorActionRole
    let action: LibraryManagementAction
}

struct LibraryManagementInspectorSceneModel: Equatable {
    let title: String
    let subtitle: String
    let details: [LibraryManagementInspectorDetailItem]
    let actions: [LibraryManagementInspectorActionItem]

    static let empty = LibraryManagementInspectorSceneModel(
        title: "选择一个项目",
        subtitle: "从文件夹、语料或回收站里选择一项，就能在这里查看详情并执行相关操作。",
        details: [],
        actions: []
    )
}

struct LibraryCorpusInfoSceneModel: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let folderName: String
    let sourceType: String
    let sourceLabelText: String
    let yearText: String
    let genreText: String
    let tagsText: String
    let importedAtText: String
    let encodingText: String
    let tokenCountText: String
    let typeCountText: String
    let sentenceCountText: String
    let paragraphCountText: String
    let characterCountText: String
    let ttrText: String
    let sttrText: String
    let representedPath: String
    let cleaningStatusTitle: String
    let cleanedAtText: String
    let originalCharacterCountText: String
    let cleanedCharacterCountText: String
    let cleaningRuleHitsText: String
}

struct LibraryCorpusMetadataEditorSceneModel: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let sourceLabel: String
    let yearLabel: String
    let genreLabel: String
    let tagsText: String
    let sourcePresetLabels: [String]
    let recentSourceLabels: [String]
    let quickYearLabels: [String]
    let commonYearLabels: [String]
    let isBatchEdit: Bool
    let allowsYearEditing: Bool
    let selectionCount: Int
}

struct LibraryIntegritySummarySceneModel: Equatable {
    let visibleCorpusCount: Int
    let missingYearCount: Int
    let missingGenreCount: Int
    let missingTagsCount: Int

    static let empty = LibraryIntegritySummarySceneModel(
        visibleCorpusCount: 0,
        missingYearCount: 0,
        missingGenreCount: 0,
        missingTagsCount: 0
    )
}

struct LibraryAutoCleaningSummarySceneModel: Equatable {
    let cleanedCount: Int
    let pendingCount: Int
    let changedCount: Int

    static let empty = LibraryAutoCleaningSummarySceneModel(
        cleanedCount: 0,
        pendingCount: 0,
        changedCount: 0
    )
}

struct LibraryImportSummarySceneModel: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let importedCountText: String
    let skippedCountText: String
    let cleanedCountText: String
    let changedCountText: String
    let ruleHitsSummaryText: String
    let firstFailureText: String
}

struct LibraryManagementSceneModel: Equatable {
    let librarySummary: String
    let currentScopeSummary: String
    let recycleSummary: String
    let statusMessage: String
    let preserveHierarchy: Bool
    let metadataFilterSummary: String?
    let autoCleaningSummary: LibraryAutoCleaningSummarySceneModel
    let integritySummary: LibraryIntegritySummarySceneModel
    let importProgress: Double?
    let importDetail: String?
    let navigationSelection: LibraryManagementNavigationSelection
    let content: LibraryManagementContentSceneModel
    let filterChips: [LibraryManagementFilterChipSceneItem]
    let overflowActions: [LibraryManagementOverflowActionSceneItem]
    let recentCorpusSetsSummary: String
    let corpusSetsSummary: String
    let folders: [LibraryManagementFolderSceneItem]
    let recentCorpusSets: [LibraryManagementCorpusSetSceneItem]
    let corpusSets: [LibraryManagementCorpusSetSceneItem]
    let corpora: [LibraryManagementCorpusSceneItem]
    let recycleEntries: [LibraryManagementRecycleSceneItem]
    let selectedCorpusSetID: String?
    let selectedFolderID: String?
    let selectedCorpusID: String?
    let selectedCorpusIDs: Set<String>
    let selectedRecycleEntryID: String?
    let inspector: LibraryManagementInspectorSceneModel?

    static let empty = LibraryManagementSceneModel(
        librarySummary: "尚未载入语料库",
        currentScopeSummary: "全部语料",
        recycleSummary: "回收站为空",
        statusMessage: "",
        preserveHierarchy: true,
        metadataFilterSummary: nil,
        autoCleaningSummary: .empty,
        integritySummary: .empty,
        importProgress: nil,
        importDetail: nil,
        navigationSelection: .allCorpora,
        content: LibraryManagementContentSceneModel(
            mode: .corpora,
            title: "全部语料",
            subtitle: "共 0 条语料",
            emptyTitle: "当前视图没有语料",
            emptyDescription: "可以切换到“全部语料”，或者直接导入新语料。"
        ),
        filterChips: [],
        overflowActions: [],
        recentCorpusSetsSummary: "最近使用 0 项",
        corpusSetsSummary: "语料集 0 项",
        folders: [],
        recentCorpusSets: [],
        corpusSets: [],
        corpora: [],
        recycleEntries: [],
        selectedCorpusSetID: nil,
        selectedFolderID: nil,
        selectedCorpusID: nil,
        selectedCorpusIDs: [],
        selectedRecycleEntryID: nil,
        inspector: nil
    )
}
