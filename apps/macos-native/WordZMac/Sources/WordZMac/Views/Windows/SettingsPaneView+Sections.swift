import SwiftUI

extension SettingsPaneView {
    var workspaceSection: some View {
        NativeWindowSection(title: t("工作区", "Workspace"), subtitle: settings.scene.workspaceSummary) {
            Toggle(t("显示欢迎页", "Show welcome screen"), isOn: $settings.showWelcomeScreen)
            Toggle(t("恢复上次工作区", "Restore previous workspace"), isOn: $settings.restoreWorkspace)
            Toggle(t("启用调试日志", "Enable debug logging"), isOn: $settings.debugLogging)
        }
    }

    var appearanceSection: some View {
        Group {
            NativeWindowSection(title: t("外观", "Appearance")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("界面语言", "Interface Language"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(t("跟随系统", "Follow System"))
                        .font(.body.weight(.semibold))

                    Text(
                        t(
                            "WordZ 会跟随 macOS 当前语言显示界面文案；本地化资源脚手架已保留，方便后续扩展更多语言。",
                            "WordZ follows the current macOS language for interface copy; the localization scaffold remains in place for future languages."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            NativeWindowSection(title: t("菜单栏", "Menu Bar")) {
                Toggle(t("显示右上角菜单栏图标", "Show menu bar icon"), isOn: $settings.showMenuBarIcon)

                Text(
                    t(
                        "菜单栏图标现已改为原生 AppKit 实现，避免启动时的彩虹圈卡死；显示切换会立即生效，点击“保存设置”后会在下次启动继续保留。",
                        "The menu bar icon now uses a native AppKit implementation to avoid launch beachball hangs; visibility changes take effect immediately and persist across launches after Save Settings."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var updatesSection: some View {
        NativeWindowSection(title: t("更新", "Updates"), subtitle: settings.scene.updateSummary) {
            Toggle(t("启用自动更新", "Enable automatic updates"), isOn: $settings.autoUpdateEnabled)
            Toggle(t("启动时检查更新", "Check for updates on launch"), isOn: $settings.checkForUpdatesOnLaunch)
            Toggle(t("后台自动下载更新", "Download updates in background"), isOn: $settings.autoDownloadUpdates)
            Toggle(
                t("下载完成后自动安装并重启", "Install and restart after download"),
                isOn: $settings.autoInstallDownloadedUpdates
            )

            Text(
                t(
                    "当前会打开已下载的安装包，并退出当前版本；安装完成后重新打开应用即可进入新版本。",
                    "WordZ opens the downloaded installer and quits the current version; reopen the app after installation completes."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            LabeledContent(t("最新可用版本", "Latest Version")) {
                Text(settings.scene.latestVersionLabel)
                    .font(.body.monospacedDigit())
            }

            if !settings.scene.latestReleaseTitle.isEmpty {
                LabeledContent(t("发布标题", "Release Title")) {
                    Text(settings.scene.latestReleaseTitle)
                }
            }

            if !settings.scene.latestReleasePublishedLabel.isEmpty {
                LabeledContent(t("发布时间", "Published At")) {
                    Text(settings.scene.latestReleasePublishedLabel)
                }
            }

            if !settings.scene.latestAssetName.isEmpty {
                LabeledContent(t("安装包", "Installer")) {
                    Text(settings.scene.latestAssetName)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            if settings.scene.isCheckingUpdates || settings.scene.isDownloadingUpdate {
                ProgressView(
                    settings.scene.isDownloadingUpdate
                    ? (settings.scene.downloadProgressLabel.isEmpty ? t("正在下载更新…", "Downloading update…") : settings.scene.downloadProgressLabel)
                    : t("正在检查更新…", "Checking for updates…")
                )
            }

            if !settings.scene.downloadedUpdateName.isEmpty {
                LabeledContent(t("已下载更新", "Downloaded Update")) {
                    Text(settings.scene.downloadedUpdateName)
                }
            }

            if !settings.scene.downloadedUpdatePath.isEmpty {
                LabeledContent(t("安装包路径", "Installer Path")) {
                    Text(settings.scene.downloadedUpdatePath)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            HStack {
                Button(t("立即检查更新", "Check Now")) { onAction(.checkForUpdatesNow) }
                if settings.scene.canDownloadUpdate {
                    Button(t("下载更新", "Download Update")) { onAction(.downloadUpdate) }
                }
                if settings.scene.canInstallDownloadedUpdate {
                    Button(t("安装已下载更新", "Install Downloaded Update")) { onAction(.installDownloadedUpdate) }
                    Button(t("在 Finder 中显示", "Reveal in Finder")) { onAction(.revealDownloadedUpdate) }
                }
            }

            HStack {
                Button(t("版本说明窗口", "Release Notes Window")) { onAction(.showReleaseNotesWindow) }
                if settings.scene.canDownloadUpdate || settings.scene.canInstallDownloadedUpdate || settings.scene.isDownloadingUpdate {
                    Button(t("打开更新窗口", "Open Update Window")) { onAction(.showUpdateWindow) }
                }
            }
        }
    }

    var recentSection: some View {
        NativeWindowSection(title: t("最近打开", "Recent Documents"), subtitle: "\(settings.scene.recentDocuments.count) \(t("条记录", "items"))") {
            if settings.scene.recentDocuments.isEmpty {
                ContentUnavailableView(
                    t("还没有最近打开记录", "No recent documents yet"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(t("打开并分析语料后，这里会出现最近访问记录。", "Open and analyze a corpus to populate this list."))
                )
            } else {
                ForEach(settings.scene.recentDocuments) { item in
                    Button {
                        onAction(.reopenRecent(item.corpusID))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }

                HStack {
                    Spacer()
                    Button(t("清空最近打开", "Clear Recent Documents")) { onAction(.clearRecentDocuments) }
                }
            }
        }
    }

    var supportSection: some View {
        NativeWindowSection(title: t("支持与诊断", "Support & Diagnostics"), subtitle: settings.scene.supportStatus) {
            HStack {
                Button(t("导出诊断包", "Export Diagnostics Bundle")) { onAction(.exportDiagnostics) }
                Button(t("打开用户数据目录", "Open User Data Folder")) { onAction(.openUserDataDirectory) }
            }

            HStack {
                Button(t("项目主页", "Project Home")) { onAction(.openProjectHome) }
                Button(t("GitHub 反馈", "GitHub Feedback")) { onAction(.openFeedback) }
            }

            HStack {
                Button(t("使用说明", "Usage Guide")) { onAction(.showHelpWindow) }
                Button(t("关于 WordZ", "About WordZ")) { onAction(.showAboutWindow) }
            }

            if !settings.scene.userDataDirectory.isEmpty {
                Text(settings.scene.userDataDirectory)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    var aboutSection: some View {
        NativeWindowSection(title: t("关于", "About"), subtitle: settings.scene.buildSummary) {
            HStack {
                Button(t("关于 WordZ", "About WordZ")) { onAction(.showAboutWindow) }
                Button(t("使用说明", "Usage Guide")) { onAction(.showHelpWindow) }
                Button(t("版本说明", "Release Notes")) { onAction(.showReleaseNotesWindow) }
            }
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
