import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func presentIssue(
        _ error: Error,
        titleZh: String,
        titleEn: String,
        recoveryAction: WorkspaceIssueRecoveryAction? = nil
    ) {
        let message = error.localizedDescription
        settings.setSupportStatus(message)
        activeIssue = WorkspaceIssueBanner(
            tone: .warning,
            title: t(titleZh, titleEn),
            message: message,
            recoveryAction: recoveryAction
        )
    }

    func clearActiveIssue() {
        activeIssue = nil
    }
}
