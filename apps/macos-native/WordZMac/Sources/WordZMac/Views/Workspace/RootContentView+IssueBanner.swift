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
                    .buttonStyle(.borderedProminent)
                }
                Button(wordZText("使用说明", "Usage Guide", mode: languageMode)) {
                    commandHandler.openHelpCenter()
                }
                Button(wordZText("导出诊断包", "Export Diagnostics Bundle", mode: languageMode)) {
                    commandHandler.exportDiagnostics()
                }
                if !viewModel.settings.scene.userDataDirectory.isEmpty {
                    Button(wordZText("打开数据目录", "Open Data Directory", mode: languageMode)) {
                        commandHandler.openUserDataDirectory()
                    }
                }
            }
        }
    }
}
