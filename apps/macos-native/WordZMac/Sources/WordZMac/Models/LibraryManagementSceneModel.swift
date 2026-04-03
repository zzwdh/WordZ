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
}

struct LibraryManagementSceneModel: Equatable {
    let librarySummary: String
    let recycleSummary: String
    let statusMessage: String
    let preserveHierarchy: Bool
    let folders: [LibraryManagementFolderSceneItem]
    let corpora: [LibraryManagementCorpusSceneItem]
    let recycleEntries: [LibraryManagementRecycleSceneItem]
    let selectedFolderID: String?
    let selectedCorpusID: String?
    let selectedRecycleEntryID: String?
    let inspector: LibraryManagementInspectorSceneModel

    static let empty = LibraryManagementSceneModel(
        librarySummary: "尚未载入语料库",
        recycleSummary: "回收站为空",
        statusMessage: "",
        preserveHierarchy: true,
        folders: [],
        corpora: [],
        recycleEntries: [],
        selectedFolderID: nil,
        selectedCorpusID: nil,
        selectedRecycleEntryID: nil,
        inspector: .empty
    )
}
