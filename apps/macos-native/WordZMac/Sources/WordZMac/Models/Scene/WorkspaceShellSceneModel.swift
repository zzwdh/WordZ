import Foundation

enum WorkspaceToolbarAction: String, Identifiable, CaseIterable {
    case refresh
    case showLibrary
    case openSelected
    case openSourceReader
    case previewCurrentCorpus
    case shareCurrentContent
    case runStats
    case runWord
    case runTokenize
    case runTopics
    case runCompare
    case runSentiment
    case runKeyword
    case runChiSquare
    case runPlot
    case runNgram
    case runCluster
    case runKWIC
    case runCollocate
    case runLocator
    case exportCurrent

    var id: String { rawValue }
}

struct WorkspaceToolbarActionItem: Identifiable, Equatable {
    let action: WorkspaceToolbarAction
    let title: String
    let isEnabled: Bool

    var id: String { action.id }
}

struct WorkspaceToolbarSceneModel: Equatable {
    let items: [WorkspaceToolbarActionItem]
}

struct WorkspaceShellSceneModel: Equatable {
    let workspaceSummary: String
    let buildSummary: String
    let toolbar: WorkspaceToolbarSceneModel
}
