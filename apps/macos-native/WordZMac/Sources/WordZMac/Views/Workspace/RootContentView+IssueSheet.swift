import SwiftUI

extension RootContentView {
    var workspaceIssueSheetBinding: Binding<WorkspaceIssueBanner?> {
        Binding(
            get: { presentedIssueBanner },
            set: { nextValue in
                if let nextValue {
                    presentedIssueBanner = nextValue
                } else {
                    dismissWorkspaceIssueSheet()
                }
            }
        )
    }

    func syncWorkspaceIssuePresentation(with banner: WorkspaceIssueBanner?) {
        guard let banner else {
            presentedIssueBanner = nil
            dismissedIssueBannerID = nil
            return
        }

        guard dismissedIssueBannerID != banner.id else { return }
        if presentedIssueBanner != banner {
            presentedIssueBanner = banner
        }
    }

    func dismissWorkspaceIssueSheet() {
        dismissedIssueBannerID = presentedIssueBanner?.id
        presentedIssueBanner = nil
    }

    func workspaceIssueSheet(_ banner: WorkspaceIssueBanner) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchIssueBanner(
                tone: banner.tone,
                title: banner.title,
                message: banner.message
            )

            VStack(alignment: .leading, spacing: 12) {
                if let recoveryAction = banner.recoveryAction {
                    Button(commandHandler.recoveryTitle(for: recoveryAction, languageMode: languageMode)) {
                        dismissWorkspaceIssueSheet()
                        Task { await commandHandler.performRecoveryAction(recoveryAction) }
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 10) {
                    Button(wordZText("使用说明", "Usage Guide", mode: languageMode)) {
                        dismissWorkspaceIssueSheet()
                        commandHandler.openHelpCenter()
                    }

                    Button(wordZText("导出诊断包", "Export Diagnostics Bundle", mode: languageMode)) {
                        dismissWorkspaceIssueSheet()
                        commandHandler.exportDiagnostics()
                    }

                    if !viewModel.settings.scene.userDataDirectory.isEmpty {
                        Button(wordZText("打开数据目录", "Open Data Directory", mode: languageMode)) {
                            dismissWorkspaceIssueSheet()
                            commandHandler.openUserDataDirectory()
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Spacer()

                Button(wordZText("稍后处理", "Dismiss", mode: languageMode)) {
                    dismissWorkspaceIssueSheet()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 460, idealWidth: 520)
    }
}
