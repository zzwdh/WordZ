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

struct WorkspaceIssueBanner: Equatable, Identifiable {
    let tone: WorkspaceIssueBannerTone
    let title: String
    let message: String
    let recoveryAction: WorkspaceIssueRecoveryAction?

    var id: String {
        "\(tone.storageID)|\(title)|\(message)|\(recoveryAction?.storageID ?? "none")"
    }
}

private extension WorkspaceIssueBannerTone {
    var storageID: String {
        switch self {
        case .info:
            return "info"
        case .warning:
            return "warning"
        case .error:
            return "error"
        }
    }
}

private extension WorkspaceIssueRecoveryAction {
    var storageID: String {
        switch self {
        case .refreshWorkspace:
            return "refreshWorkspace"
        case .checkForUpdates:
            return "checkForUpdates"
        case .exportDiagnostics:
            return "exportDiagnostics"
        }
    }
}
