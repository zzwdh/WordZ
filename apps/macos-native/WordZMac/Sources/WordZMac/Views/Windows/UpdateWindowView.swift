import AppKit
import SwiftUI

struct UpdateWindowView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel
    @State private var window: NSWindow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NativeWindowHeader(title: windowTitle, subtitle: windowSubtitle) {
                    if workspace.settings.scene.isCheckingUpdates || workspace.settings.scene.isDownloadingUpdate {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                WorkbenchIssueBanner(
                    tone: bannerTone,
                    title: bannerTitle,
                    message: bannerMessage
                )

                NativeWindowSection(title: t("安装流程", "Install Flow"), subtitle: workspace.settings.scene.updateSummary) {
                    LabeledContent(t("当前版本", "Current Version")) {
                        Text(displayCurrentVersion)
                            .font(.body.monospacedDigit())
                    }

                    LabeledContent(t("目标版本", "Target Version")) {
                        Text(displayLatestVersion)
                            .font(.body.monospacedDigit())
                    }

                    if !workspace.settings.scene.latestAssetName.isEmpty {
                        LabeledContent(t("安装包", "Installer")) {
                            Text(workspace.settings.scene.latestAssetName)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }

                    if workspace.settings.scene.isDownloadingUpdate {
                        ProgressView(
                            workspace.settings.scene.downloadProgressLabel.isEmpty
                                ? t("正在准备更新…", "Preparing update…")
                                : workspace.settings.scene.downloadProgressLabel
                        )
                    }

                    Text(
                        t(
                            "点击“安装并重启”后，WordZ 会先打开安装包并退出当前版本；安装完成后重新打开即可进入新版本。",
                            "When you choose Install and Restart, WordZ opens the installer and quits the current version. Reopen the app after installation completes."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                NativeWindowSection(title: t("版本亮点", "Release Highlights"), subtitle: releaseNotesSubtitle) {
                    if releaseNotes.isEmpty {
                        Text(t("当前没有可显示的版本说明。", "No release notes are available right now."))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(releaseNotes.enumerated()), id: \.offset) { _, line in
                            Text("• \(line)")
                        }
                    }
                }

                HStack(alignment: .center, spacing: 10) {
                    Button(t("取消", "Cancel")) {
                        closeWindow()
                    }

                    Spacer(minLength: 12)

                    Button(t("查看发布页", "Open Release Page")) {
                        Task { await workspace.openReleaseNotes() }
                    }

                    Button(t("关闭自动下载安装", "Turn Off Auto Install")) {
                        Task {
                            await workspace.disableAutomaticUpdateDownloadsAndInstall()
                            closeWindow()
                        }
                    }
                    .disabled(!workspace.settings.autoDownloadUpdates && !workspace.settings.autoInstallDownloadedUpdates)

                    Button(t("安装并重启", "Install and Restart")) {
                        Task { await workspace.installLatestUpdateAndRestart() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(installButtonDisabled)
                }
            }
            .padding(20)
        }
        .adaptiveWindowScaffold(for: .updatePrompt)
        .bindWindowRoute(.updatePrompt, titleProvider: { _ in
            windowTitle
        }) { resolvedWindow in
            window = resolvedWindow
        }
        .focusedValue(\.workspaceCommandContext, workspace.commandContext(for: .updatePrompt))
        .frame(minWidth: 560, minHeight: 420)
    }

    private var displayCurrentVersion: String {
        workspace.updateState.currentVersion.isEmpty
            ? workspace.currentVersionForUpdateChecks
            : workspace.updateState.currentVersion
    }

    private var displayLatestVersion: String {
        workspace.settings.scene.latestVersionLabel.isEmpty
            ? t("未知", "Unknown")
            : workspace.settings.scene.latestVersionLabel
    }

    private var bannerTone: WorkspaceIssueBannerTone {
        if workspace.settings.scene.canInstallDownloadedUpdate {
            return .info
        }
        if workspace.settings.scene.canDownloadUpdate || workspace.settings.scene.isDownloadingUpdate {
            return .warning
        }
        return .info
    }

    private var bannerTitle: String {
        if workspace.settings.scene.canInstallDownloadedUpdate {
            return t("更新已准备好安装", "Update Ready to Install")
        }
        if workspace.settings.scene.isDownloadingUpdate {
            return t("正在准备安装包", "Preparing Installer")
        }
        if workspace.settings.scene.canDownloadUpdate {
            return t("发现新版本", "New Version Available")
        }
        if workspace.settings.scene.isCheckingUpdates {
            return t("正在检查更新", "Checking for Updates")
        }
        return t("更新状态", "Update Status")
    }

    private var bannerMessage: String {
        if workspace.settings.scene.canInstallDownloadedUpdate {
            return workspace.settings.scene.downloadedUpdateName
        }
        if workspace.settings.scene.isDownloadingUpdate,
           !workspace.settings.scene.downloadProgressLabel.isEmpty {
            return workspace.settings.scene.downloadProgressLabel
        }
        return workspace.settings.scene.updateSummary
    }

    private var releaseNotes: [String] {
        workspace.settings.scene.latestReleaseNotes.isEmpty
            ? workspace.settings.scene.releaseNotes
            : workspace.settings.scene.latestReleaseNotes
    }

    private var releaseNotesSubtitle: String {
        workspace.settings.scene.latestReleaseTitle.isEmpty
            ? displayLatestVersion
            : workspace.settings.scene.latestReleaseTitle
    }

    private var windowTitle: String {
        if workspace.settings.scene.canInstallDownloadedUpdate {
            return t("准备安装更新", "Ready to Install Update")
        }
        if workspace.settings.scene.canDownloadUpdate || workspace.settings.scene.isDownloadingUpdate {
            return t("启动时发现新更新", "Update Found at Launch")
        }
        return t("更新", "Update")
    }

    private var windowSubtitle: String {
        workspace.settings.scene.latestReleasePublishedLabel.isEmpty
            ? workspace.settings.scene.updateSummary
            : workspace.settings.scene.latestReleasePublishedLabel
    }

    private var installButtonDisabled: Bool {
        workspace.settings.scene.isCheckingUpdates
            || workspace.settings.scene.isDownloadingUpdate
            || (!workspace.settings.scene.canInstallDownloadedUpdate && !workspace.settings.scene.canDownloadUpdate)
    }

    private func closeWindow() {
        window?.close()
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
