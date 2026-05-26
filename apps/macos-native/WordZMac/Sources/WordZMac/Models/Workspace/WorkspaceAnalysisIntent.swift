import Foundation

enum WorkspaceAnalysisIntent: String, CaseIterable, Equatable, Sendable {
    case stats
    case word
    case tokenize
    case topics
    case compare
    case sentiment
    case keyword
    case chiSquare
    case plot
    case ngram
    case cluster
    case kwic
    case collocate
    case locator

    init?(toolbarAction: WorkspaceToolbarAction) {
        guard let analysisIntent = WorkspaceActionRegistry.analysisIntent(for: toolbarAction) else {
            return nil
        }
        self = analysisIntent
    }

    init?(nativeCommand: NativeAppCommand) {
        guard let analysisIntent = WorkspaceActionRegistry.analysisIntent(for: nativeCommand) else {
            return nil
        }
        self = analysisIntent
    }

    var toolbarAction: WorkspaceToolbarAction {
        WorkspaceActionRegistry.toolbarAction(for: self)
    }

    var nativeCommand: NativeAppCommand {
        WorkspaceActionRegistry.nativeCommand(for: toolbarAction) ?? .refreshWorkspace
    }
}
