import Foundation

@MainActor
extension MainWorkspaceViewModel {
    var issueBanner: WorkspaceIssueBanner? {
        if sidebar.scene.engineState == .failed {
            return WorkspaceIssueBanner(
                tone: .error,
                title: t("本地引擎启动失败", "Local Engine Startup Failed"),
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
