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
    let databaseFileName: String
    let representedPath: String
    let sourceSummary: String
    let metadataSummary: String
    let readiness: LibraryCorpusReadinessSceneModel
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
    let isSmart: Bool
    let kindTitle: String
    let snapshotSummary: String
    let corpusCountText: String
    let filterSummary: String
    let isSelected: Bool
}

enum LibraryCorpusReadinessLevel: Equatable {
    case ready
    case attention
    case blocked
}

struct LibraryCorpusReadinessSceneModel: Equatable {
    let level: LibraryCorpusReadinessLevel
    let title: String
    let scoreText: String
    let detailText: String
    let issueTitles: [String]
}

struct LibraryReadinessSummarySceneModel: Equatable {
    let readyCount: Int
    let attentionCount: Int
    let blockedCount: Int
    let averageScoreText: String
    let actionSummaryText: String

    static let empty = LibraryReadinessSummarySceneModel(
        readyCount: 0,
        attentionCount: 0,
        blockedCount: 0,
        averageScoreText: "0%",
        actionSummaryText: "暂无可检查语料"
    )
}

struct LibraryMetadataStudioSceneModel: Equatable {
    let visibleCorpusCount: Int
    let selectedCorpusCount: Int
    let completeMetadataCount: Int
    let missingYearCount: Int
    let missingGenreCount: Int
    let missingTagsCount: Int
    let completionText: String
    let actionHintText: String

    static let empty = LibraryMetadataStudioSceneModel(
        visibleCorpusCount: 0,
        selectedCorpusCount: 0,
        completeMetadataCount: 0,
        missingYearCount: 0,
        missingGenreCount: 0,
        missingTagsCount: 0,
        completionText: "0%",
        actionHintText: "选择语料后可批量补齐元数据"
    )
}

struct LibraryImportPreflightWarningSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}

struct LibraryImportPreflightPreviewItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isSupported: Bool
}

struct LibraryImportPreflightSceneModel: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let paths: [String]
    let defaultCorpusName: String
    let fileCountText: String
    let folderCountText: String
    let supportedCountText: String
    let unsupportedCountText: String
    let duplicateRiskCountText: String
    let preserveHierarchyText: String
    let warnings: [LibraryImportPreflightWarningSceneItem]
    let previewItems: [LibraryImportPreflightPreviewItem]
}

struct LibraryManagementRecycleSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let typeLabel: String
}

enum LibraryManagementNavigationSelection: Hashable, Equatable {
    case allCorpora
    case corpusBuilder
    case folder(String)
    case savedCorpusSet(String)
    case recentCorpusSet(String)
    case recycleBin
}

enum LibraryManagementContentMode: Equatable {
    case corpora
    case corpusBuilder
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

enum LibraryManagementInspectorStatusLevel: Equatable {
    case info
    case success
    case warning
    case blocked
}

struct LibraryManagementInspectorStatusItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let level: LibraryManagementInspectorStatusLevel
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
    let statusItems: [LibraryManagementInspectorStatusItem]
    let details: [LibraryManagementInspectorDetailItem]
    let actions: [LibraryManagementInspectorActionItem]

    static let empty = LibraryManagementInspectorSceneModel(
        title: "选择一个项目",
        subtitle: "从文件夹、语料或回收站里选择一项，就能在这里查看详情并执行相关操作。",
        statusItems: [],
        details: [],
        actions: []
    )
}

struct LibraryCorpusInfoSceneModel: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let projectIDText: String
    let databaseFileNameText: String
    let dbProjectSummaryText: String
    let sourceChainText: String
    let analysisReadinessTitle: String
    let analysisReadinessDetail: String
    let chineseAnalysisText: String
    let missingActionText: String
    let folderName: String
    let sourceType: String
    let sourceLabelText: String
    let yearText: String
    let genreText: String
    let tagsText: String
    let importedAtText: String
    let encodingText: String
    let fileCountText: String
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
    let readinessSummary: LibraryReadinessSummarySceneModel
    let metadataStudio: LibraryMetadataStudioSceneModel
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
        readinessSummary: .empty,
        metadataStudio: .empty,
        importProgress: nil,
        importDetail: nil,
        navigationSelection: .allCorpora,
        content: LibraryManagementContentSceneModel(
            mode: .corpora,
            title: "Corpus Library",
            subtitle: "0 条语料 · .db 格式",
            emptyTitle: "还没有语料",
            emptyDescription: "从 TXT、DOCX、PDF 导入文件后即可开始分析。"
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
