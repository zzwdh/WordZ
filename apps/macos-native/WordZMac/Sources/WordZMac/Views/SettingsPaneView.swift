import SwiftUI

private enum SettingsSection: CaseIterable, Identifiable {
    case workspace
    case appearance
    case updates
    case recent
    case support
    case about

    var id: String {
        switch self {
        case .workspace:
            return "workspace"
        case .appearance:
            return "appearance"
        case .updates:
            return "updates"
        case .recent:
            return "recent"
        case .support:
            return "support"
        case .about:
            return "about"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .workspace:
            return wordZText("工作区", "Workspace", mode: mode)
        case .appearance:
            return wordZText("外观", "Appearance", mode: mode)
        case .updates:
            return wordZText("更新", "Updates", mode: mode)
        case .recent:
            return wordZText("最近打开", "Recent", mode: mode)
        case .support:
            return wordZText("支持", "Support", mode: mode)
        case .about:
            return wordZText("关于", "About", mode: mode)
        }
    }

    func subtitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .workspace:
            return wordZText("欢迎页、工作区恢复与调试偏好", "Welcome screen, restore behavior, and debug preferences", mode: mode)
        case .appearance:
            return wordZText("缩放、字体和显示密度", "Zoom, fonts, and display density", mode: mode)
        case .updates:
            return wordZText("检查更新、后台下载与版本说明", "Update checks, background downloads, and release notes", mode: mode)
        case .recent:
            return wordZText("最近打开语料与恢复入口", "Recent corpora and resume shortcuts", mode: mode)
        case .support:
            return wordZText("诊断导出、用户数据与反馈入口", "Diagnostics, user data, and feedback actions", mode: mode)
        case .about:
            return wordZText("构建信息、帮助与版本说明", "Build info, help, and release notes", mode: mode)
        }
    }

    var symbolName: String {
        switch self {
        case .workspace:
            return "square.grid.2x2"
        case .appearance:
            return "paintbrush"
        case .updates:
            return "arrow.triangle.2.circlepath"
        case .recent:
            return "clock.arrow.circlepath"
        case .support:
            return "lifepreserver"
        case .about:
            return "info.circle"
        }
    }
}

struct SettingsPaneView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var settings: WorkspaceSettingsViewModel
    let onAction: (SettingsPaneAction) -> Void

    @State private var selectedSection: SettingsSection? = .workspace

    var body: some View {
        HSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title(in: languageMode), systemImage: section.symbolName)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180, idealWidth: 190)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WorkbenchHeaderCard(
                        title: t("设置", "Settings"),
                        subtitle: currentSection.subtitle(in: languageMode)
                    )

                    sectionContent

                    HStack {
                        Spacer()
                        Button(t("保存设置", "Save Settings")) { onAction(.save) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .workspace, nil:
            workspaceSection
        case .appearance:
            appearanceSection
        case .updates:
            updatesSection
        case .recent:
            recentSection
        case .support:
            supportSection
        case .about:
            aboutSection
        }
    }

    private var currentSection: SettingsSection {
        selectedSection ?? .workspace
    }

    private var workspaceSection: some View {
        WorkbenchPaneCard(title: t("工作区", "Workspace"), subtitle: settings.scene.workspaceSummary) {
            Toggle(t("显示欢迎页", "Show welcome screen"), isOn: $settings.showWelcomeScreen)
            Toggle(t("恢复上次工作区", "Restore previous workspace"), isOn: $settings.restoreWorkspace)
            Toggle(t("启用调试日志", "Enable debug logging"), isOn: $settings.debugLogging)
        }
    }

    private var appearanceSection: some View {
        WorkbenchPaneCard(title: t("外观", "Appearance"), subtitle: t("调整窗口缩放、字体和显示风格", "Adjust zoom, fonts, and visual density")) {
            Picker(t("界面语言", "Interface Language"), selection: $settings.languageMode) {
                ForEach(AppLanguageMode.allCases) { mode in
                    Text(mode.pickerLabel).tag(mode)
                }
            }
            .pickerStyle(.menu)

            LabeledContent(t("缩放", "Zoom")) {
                Text(settings.scene.zoomLabel)
                    .monospacedDigit()
            }
            Slider(value: $settings.zoom, in: 80...150, step: 10)

            LabeledContent(t("字体缩放", "Font Scale")) {
                Text(settings.scene.fontScaleLabel)
                    .monospacedDigit()
            }
            Slider(value: $settings.fontScale, in: 90...140, step: 10)

            Picker(t("字体风格", "Font Style"), selection: $settings.fontFamily) {
                Text(t("系统", "System")).tag("system")
                Text(t("圆角", "Rounded")).tag("rounded")
                Text(t("等宽", "Monospaced")).tag("monospaced")
            }
            .pickerStyle(.segmented)
        }
    }

    private var updatesSection: some View {
        WorkbenchPaneCard(title: t("更新", "Updates"), subtitle: settings.scene.updateSummary) {
            Toggle(t("启用自动更新", "Enable automatic updates"), isOn: $settings.autoUpdateEnabled)
            Toggle(t("启动时检查更新", "Check for updates on launch"), isOn: $settings.checkForUpdatesOnLaunch)
            Toggle(t("后台自动下载更新", "Download updates in background"), isOn: $settings.autoDownloadUpdates)

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
                Button(t("任务中心", "Task Center")) { onAction(.showTaskCenter) }
                Button(t("版本说明窗口", "Release Notes Window")) { onAction(.showReleaseNotesWindow) }
            }
        }
    }

    private var recentSection: some View {
        WorkbenchPaneCard(title: t("最近打开", "Recent Documents"), subtitle: "\(settings.scene.recentDocuments.count) \(t("条记录", "items"))") {
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

    private var supportSection: some View {
        WorkbenchPaneCard(title: t("支持与诊断", "Support & Diagnostics"), subtitle: settings.scene.supportStatus) {
            HStack {
                Button(t("导出诊断", "Export Diagnostics")) { onAction(.exportDiagnostics) }
                Button(t("打开用户数据目录", "Open User Data Folder")) { onAction(.openUserDataDirectory) }
            }

            HStack {
                Button(t("项目主页", "Project Home")) { onAction(.openProjectHome) }
                Button(t("GitHub 反馈", "GitHub Feedback")) { onAction(.openFeedback) }
            }

            HStack {
                Button(t("帮助中心", "Help Center")) { onAction(.showHelpWindow) }
                Button(t("关于 WordZ", "About WordZ")) { onAction(.showAboutWindow) }
            }

            Text(settings.scene.taskCenterSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !settings.scene.userDataDirectory.isEmpty {
                Text(settings.scene.userDataDirectory)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var aboutSection: some View {
        WorkbenchPaneCard(title: t("关于", "About"), subtitle: settings.scene.buildSummary) {
            Text(t("关于、帮助与版本说明已经拆成独立窗口，方便在工作区中随时查阅。", "About, help, and release notes now live in dedicated windows for quick access while you work."))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button(t("关于 WordZ", "About WordZ")) { onAction(.showAboutWindow) }
                Button(t("帮助中心", "Help Center")) { onAction(.showHelpWindow) }
                Button(t("版本说明", "Release Notes")) { onAction(.showReleaseNotesWindow) }
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
