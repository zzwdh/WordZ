import Foundation

struct WorkspaceSidebarCorpusOptionSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

struct WorkspaceSidebarCorpusSetSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
}

struct WorkspaceSidebarCorpusSlotSceneModel: Equatable {
    let title: String
    let corpusID: String?
    let summary: String
    let detail: String
    let isOptional: Bool
}

struct WorkspaceCurrentCorpusSceneModel: Equatable {
    let title: String
    let subtitle: String
}

struct WorkspaceSidebarAnalysisSceneItem: Identifiable, Equatable {
    let tab: WorkspaceDetailTab
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let isSelected: Bool

    var id: String { tab.id }
}

struct WorkspaceSidebarResultsSceneModel: Equatable {
    let title: String
    let subtitle: String
    let exportTitle: String
}

enum WorkspaceSidebarEngineState: Equatable {
    case connecting
    case connected
    case failed
}

struct WorkspaceSidebarSceneModel: Equatable {
    let appName: String
    let versionLabel: String
    let engineStatus: String
    let engineState: WorkspaceSidebarEngineState
    let targetCorpus: WorkspaceSidebarCorpusSlotSceneModel
    let referenceCorpus: WorkspaceSidebarCorpusSlotSceneModel
    let selectedCorpusSetSummary: String?
    let corpusOptions: [WorkspaceSidebarCorpusOptionSceneItem]
    let corpusSets: [WorkspaceSidebarCorpusSetSceneItem]
    let metadataFilterSummary: String?
    let analysisViews: [WorkspaceSidebarAnalysisSceneItem]
    let results: WorkspaceSidebarResultsSceneModel?
    let errorMessage: String

    var currentCorpus: WorkspaceCurrentCorpusSceneModel? {
        guard targetCorpus.corpusID != nil else { return nil }
        return WorkspaceCurrentCorpusSceneModel(title: targetCorpus.summary, subtitle: targetCorpus.detail)
    }

    static let empty = WorkspaceSidebarSceneModel(
        appName: "WordZ",
        versionLabel: "mac native preview",
        engineStatus: "正在连接本地引擎...",
        engineState: .connecting,
        targetCorpus: WorkspaceSidebarCorpusSlotSceneModel(
            title: "Target Corpus",
            corpusID: nil,
            summary: "未选择语料",
            detail: "Select a target corpus",
            isOptional: false
        ),
        referenceCorpus: WorkspaceSidebarCorpusSlotSceneModel(
            title: "Reference Corpus",
            corpusID: nil,
            summary: "Optional",
            detail: "Select a reference corpus",
            isOptional: true
        ),
        selectedCorpusSetSummary: nil,
        corpusOptions: [],
        corpusSets: [],
        metadataFilterSummary: nil,
        analysisViews: [],
        results: nil,
        errorMessage: ""
    )
}
