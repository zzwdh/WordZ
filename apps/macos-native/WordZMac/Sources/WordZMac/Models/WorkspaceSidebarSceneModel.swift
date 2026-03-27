import Foundation

struct WorkspaceSidebarCorpusSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
}

struct WorkspaceSidebarActionItem: Identifiable, Equatable {
    let action: SidebarAction
    let title: String
    let isEnabled: Bool

    var id: String { action.id }
}

struct WorkspaceCurrentCorpusSceneModel: Equatable {
    let title: String
    let subtitle: String
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
    let actions: [WorkspaceSidebarActionItem]
    let currentCorpus: WorkspaceCurrentCorpusSceneModel?
    let corpora: [WorkspaceSidebarCorpusSceneItem]
    let errorMessage: String

    static let empty = WorkspaceSidebarSceneModel(
        appName: "WordZ",
        versionLabel: "mac native preview",
        engineStatus: "正在连接本地引擎...",
        engineState: .connecting,
        actions: [],
        currentCorpus: nil,
        corpora: [],
        errorMessage: ""
    )
}
