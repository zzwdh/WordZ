import Foundation

enum WorkspaceIssueBannerTone: Equatable {
    case info
    case warning
    case error
}

enum WorkspaceIssueRecoveryAction: Equatable {
    case refreshWorkspace
    case checkForUpdates
    case exportDiagnostics
}

struct WorkspaceIssueBanner: Equatable {
    let tone: WorkspaceIssueBannerTone
    let title: String
    let message: String
    let recoveryAction: WorkspaceIssueRecoveryAction?
}
