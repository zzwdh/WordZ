import Foundation

@MainActor
extension MainWorkspaceViewModel {
    var issueBanner: WorkspaceIssueBanner? {
        if sidebar.scene.engineState == .failed {
            return WorkspaceIssueBanner(
                tone: .error,
                title: t("分析功能准备失败", "Analysis Features Unavailable"),
                message: sidebar.scene.errorMessage.isEmpty ? sidebar.scene.engineStatus : sidebar.scene.errorMessage,
                recoveryAction: .refreshWorkspace
            )
        }
        if !sidebar.scene.errorMessage.isEmpty {
            return WorkspaceIssueBanner(
                tone: .warning,
                title: t("当前工作区需要处理", "Workspace Attention Needed"),
                message: sidebar.scene.errorMessage,
                recoveryAction: .refreshWorkspace
            )
        }
        return activeIssue
    }
}
