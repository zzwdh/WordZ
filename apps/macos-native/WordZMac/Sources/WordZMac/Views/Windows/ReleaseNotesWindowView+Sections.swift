import SwiftUI

extension ReleaseNotesWindowView {
    var releaseNotesWindowContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(
                title: t("版本说明", "Release Notes"),
                subtitle: workspace.settings.scene.latestReleaseTitle.isEmpty
                    ? workspace.settings.scene.latestVersionLabel
                    : workspace.settings.scene.latestReleaseTitle
            ) {
                Button(t("打开发布页", "Open Release Page")) {
                    Task { await workspace.openReleaseNotes() }
                }
            }
            releaseNotesUpdateStatusSection
            latestReleaseSection
        }
        .padding(20)
    }

    var releaseNotesUpdateStatusSection: some View {
        NativeWindowSection(title: t("更新状态", "Update Status"), subtitle: workspace.settings.scene.updateSummary) {
            if !workspace.settings.scene.downloadedUpdateName.isEmpty {
                WorkbenchIssueBanner(
                    tone: .info,
                    title: t("已下载更新可安装", "Downloaded update ready to install"),
                    message: workspace.settings.scene.downloadedUpdateName
                ) {
                    HStack {
                        Button(t("安装更新", "Install Update")) {
                            Task { await workspace.installDownloadedUpdate() }
                        }
                        Button(t("在 Finder 中显示", "Reveal in Finder")) {
                            Task { await workspace.revealDownloadedUpdate() }
                        }
                    }
                }
            } else {
                Text(workspace.settings.scene.updateSummary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(t("立即检查更新", "Check for Updates")) {
                    Task { await workspace.checkForUpdatesNow() }
                }
                if workspace.settings.scene.canDownloadUpdate {
                    Button(t("下载更新", "Download Update")) {
                        Task { await workspace.downloadLatestUpdate() }
                    }
                }
            }
        }
    }

    var latestReleaseSection: some View {
        NativeWindowSection(title: t("最近更新", "Latest Release"), subtitle: workspace.settings.scene.updateSummary) {
            if !workspace.settings.scene.latestReleasePublishedLabel.isEmpty {
                LabeledContent(t("发布时间", "Published At")) {
                    Text(workspace.settings.scene.latestReleasePublishedLabel)
                }
            }

            if !workspace.settings.scene.latestAssetName.isEmpty {
                LabeledContent(t("安装包", "Installer")) {
                    Text(workspace.settings.scene.latestAssetName)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            if releaseNoteLines.isEmpty {
                Text(t("当前没有可显示的版本说明。", "No release notes available."))
                    .foregroundStyle(.secondary)
            } else {
                Text(t("主要改动", "Highlights"))
                    .font(.headline)
                ForEach(Array(releaseNoteLines.enumerated()), id: \.offset) { _, line in
                    Text("• \(line)")
                }
            }
        }
    }

    var releaseNoteLines: [String] {
        workspace.settings.scene.latestReleaseNotes.isEmpty
            ? workspace.settings.scene.releaseNotes
            : workspace.settings.scene.latestReleaseNotes
    }
}
