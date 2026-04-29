import SwiftUI

extension RootContentView {
    @ViewBuilder
    var workspaceIssueBanner: some View {
        if let banner = viewModel.issueBanner {
            VStack(spacing: 12) {
                issueBannerView(banner)
            }
            .padding(.horizontal, WordZTheme.pagePadding)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    func issueBannerView(_ banner: WorkspaceIssueBanner) -> some View {
        WorkbenchIssueBanner(
            tone: banner.tone,
            title: banner.title,
            message: banner.message
        ) {
            HStack(spacing: 10) {
                if let recoveryAction = banner.recoveryAction {
                    Button(commandHandler.recoveryTitle(for: recoveryAction, languageMode: languageMode)) {
                        Task { await commandHandler.performRecoveryAction(recoveryAction) }
                    }
                    .adaptiveGlassButtonStyle(prominent: true)
                }
                Button(wordZText("使用说明", "Usage Guide", mode: languageMode)) {
                    commandHandler.openHelpCenter()
                }
                .adaptiveGlassButtonStyle()
                Button(wordZText("导出诊断包", "Export Diagnostics Bundle", mode: languageMode)) {
                    commandHandler.exportDiagnostics()
                }
                .adaptiveGlassButtonStyle()
                if !viewModel.settings.scene.userDataDirectory.isEmpty {
                    Button(wordZText("打开数据目录", "Open Data Directory", mode: languageMode)) {
                        commandHandler.openUserDataDirectory()
                    }
                    .adaptiveGlassButtonStyle()
                }
                if viewModel.activeIssue == banner {
                    Button(wordZText("稍后处理", "Dismiss", mode: languageMode)) {
                        viewModel.clearActiveIssue()
                    }
                    .adaptiveGlassButtonStyle()
                }
            }
        }
    }
}
