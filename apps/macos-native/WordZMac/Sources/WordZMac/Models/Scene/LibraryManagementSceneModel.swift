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
}

struct LibraryCorpusMetadataEditorSceneModel: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let sourceLabel: String
    let yearLabel: String
    let genreLabel: String
    let tagsText: String
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

struct LibraryManagementSceneModel: Equatable {
    let librarySummary: String
    let recycleSummary: String
    let statusMessage: String
    let preserveHierarchy: Bool
    let metadataFilterSummary: String?
    let integritySummary: LibraryIntegritySummarySceneModel
    let importProgress: Double?
    let importDetail: String?
    let corpusSetsSummary: String
    let folders: [LibraryManagementFolderSceneItem]
    let corpusSets: [LibraryManagementCorpusSetSceneItem]
    let corpora: [LibraryManagementCorpusSceneItem]
    let recycleEntries: [LibraryManagementRecycleSceneItem]
    let selectedCorpusSetID: String?
    let selectedFolderID: String?
    let selectedCorpusID: String?
    let selectedCorpusIDs: Set<String>
    let selectedRecycleEntryID: String?
    let inspector: LibraryManagementInspectorSceneModel

    static let empty = LibraryManagementSceneModel(
        librarySummary: "尚未载入语料库",
        recycleSummary: "回收站为空",
        statusMessage: "",
        preserveHierarchy: true,
        metadataFilterSummary: nil,
        integritySummary: .empty,
        importProgress: nil,
        importDetail: nil,
        corpusSetsSummary: "语料集 0 项",
        folders: [],
        corpusSets: [],
        corpora: [],
        recycleEntries: [],
        selectedCorpusSetID: nil,
        selectedFolderID: nil,
        selectedCorpusID: nil,
        selectedCorpusIDs: [],
        selectedRecycleEntryID: nil,
        inspector: .empty
    )
}
