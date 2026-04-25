import Foundation

enum WorkspaceToolbarAction: String, Identifiable, CaseIterable {
    case refresh
    case showLibrary
    case openSelected
    case openSourceReader
    case annotationControls
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
    let annotationSummary: String
    let toolbar: WorkspaceToolbarSceneModel

    init(
        workspaceSummary: String,
        buildSummary: String,
        annotationSummary: String = "",
        toolbar: WorkspaceToolbarSceneModel
    ) {
        self.workspaceSummary = workspaceSummary
        self.buildSummary = buildSummary
        self.annotationSummary = annotationSummary
        self.toolbar = toolbar
    }
}
