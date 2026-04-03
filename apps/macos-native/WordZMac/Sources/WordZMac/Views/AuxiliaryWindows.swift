import SwiftUI

struct LibraryWindowView: View {
    @ObservedObject var workspace: MainWorkspaceViewModel
    @StateObject private var dispatcher: WorkspaceActionDispatcher

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
        _dispatcher = StateObject(wrappedValue: WorkspaceActionDispatcher(workspace: workspace))
    }

    var body: some View {
        LibraryManagementView(
            viewModel: workspace.library,
            onAction: dispatcher.handleLibraryAction
        )
        .task {
            await workspace.initializeIfNeeded()
            await workspace.refreshLibraryManagement()
        }
        .frame(minWidth: 1120, minHeight: 760)
    }
}

struct SettingsWindowView: View {
    @ObservedObject var workspace: MainWorkspaceViewModel
    @StateObject private var dispatcher: WorkspaceActionDispatcher

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
        _dispatcher = StateObject(wrappedValue: WorkspaceActionDispatcher(workspace: workspace))
    }

    var body: some View {
        SettingsPaneView(
            settings: workspace.settings,
            onAction: dispatcher.handleSettingsAction
        )
        .task {
            await workspace.initializeIfNeeded()
            workspace.syncSceneGraph(source: .settings)
        }
        .frame(minWidth: 980, minHeight: 720)
    }
}

struct TaskCenterWindowView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(
                title: t("任务中心", "Task Center"),
                subtitle: workspace.taskCenter.scene.summary
            ) {
                Button(t("清理已完成", "Clear Completed")) {
                    workspace.clearFinishedTasks()
                }
                .disabled(workspace.taskCenter.scene.items.allSatisfy { $0.state == .running })
            }

            metricsRow

            if workspace.taskCenter.scene.items.isEmpty {
                ContentUnavailableView(
                    t("当前没有后台任务", "No background tasks"),
                    systemImage: "checklist",
                    description: Text(t("更新检查、更新下载和诊断导出会在这里显示进度与结果。", "Update checks, downloads, and diagnostic exports will appear here."))
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(workspace.taskCenter.scene.items) { item in
                            WorkbenchPaneCard(title: item.title, subtitle: item.detail) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 12) {
                                        Label(item.state.displayLabel(in: languageMode), systemImage: item.state.symbolName)
                                            .symbolRenderingMode(.multicolor)

                                        Spacer()

                                        if item.state == .running {
                                            Text(item.progressLabel(in: languageMode))
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if item.state == .running {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ProgressView(value: item.normalizedProgress)
                                                .frame(maxWidth: .infinity)
                                                .tint(.accentColor)
                                            Text(item.detail)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }

                                    if let action = item.primaryAction {
                                        HStack {
                                            Spacer()
                                            Button(action.title(in: languageMode)) {
                                                Task {
                                                    await workspace.performTaskAction(action)
                                                }
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            WorkbenchMetricCard(
                title: t("进行中", "Running"),
                value: "\(workspace.taskCenter.scene.runningCount)"
            )
            WorkbenchMetricCard(
                title: t("已完成", "Completed"),
                value: "\(workspace.taskCenter.scene.completedCount)"
            )
            WorkbenchMetricCard(
                title: t("失败", "Failed"),
                value: "\(workspace.taskCenter.scene.failedCount)"
            )
            WorkbenchMetricCard(
                title: t("整体进度", "Overall Progress"),
                value: workspace.taskCenter.scene.aggregateProgress.map { "\(Int(($0 * 100).rounded()))%" } ?? "—",
                subtitle: workspace.taskCenter.scene.runningCount > 0
                    ? t("按当前运行任务计算", "Based on currently running tasks")
                    : t("当前没有运行中的任务", "No tasks are currently running")
            )
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct AboutWindowView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            WorkbenchHeaderCard(
                title: workspace.sceneGraph.context.appName,
                subtitle: workspace.sceneGraph.context.versionLabel
            ) {
                Text(workspace.sceneGraph.context.buildSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

                WorkbenchPaneCard(title: t("原生版概览", "Native Overview"), subtitle: t("纯 Swift 宿主与本地引擎", "Pure Swift host with native engine")) {
                    Text(t("当前原生版已经支持语料管理、主分析工作流、工作区恢复、导出、更新检查和原生命令体系。", "The native app now supports corpus management, the main analysis workflow, workspace restore, export, update checks, and native commands."))
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        WorkbenchMetricCard(title: t("版本", "Version"), value: workspace.sceneGraph.context.versionLabel)
                        WorkbenchMetricCard(title: t("工作区", "Workspace"), value: workspace.sceneGraph.context.workspaceSummary)
                        WorkbenchMetricCard(title: t("语言", "Language"), value: workspace.settings.languageMode.pickerLabel)
                        WorkbenchMetricCard(title: t("更新状态", "Update Status"), value: workspace.settings.scene.latestVersionLabel, subtitle: workspace.settings.scene.updateSummary)
                    }
                }

                WorkbenchPaneCard(title: t("快速操作", "Quick Actions"), subtitle: t("常用宿主入口", "Common host actions")) {
                    HStack {
                        Button(t("检查更新", "Check for Updates")) {
                            Task { await workspace.checkForUpdatesNow() }
                        }
                        Button(t("项目主页", "Project Home")) {
                            Task { await workspace.openProjectHome() }
                        }
                        Button(t("GitHub 反馈", "GitHub Feedback")) {
                            Task { await workspace.openFeedback() }
                        }
                    }
                }

                WorkbenchPaneCard(title: t("支持状态", "Support Status"), subtitle: workspace.settings.scene.supportStatus) {
                    Text(workspace.settings.scene.supportStatus)
                        .fixedSize(horizontal: false, vertical: true)
                    if !workspace.settings.scene.userDataDirectory.isEmpty {
                        Button(t("打开用户数据目录", "Open User Data Directory")) {
                            Task { await workspace.openUserDataDirectory() }
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 460, minHeight: 360)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct HelpCenterWindowView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WorkbenchHeaderCard(title: t("使用说明", "Usage Guide")) {
                    Button(t("打开项目主页", "Open Project Home")) {
                        Task { await workspace.openProjectHome() }
                    }
                }

                WorkbenchPaneCard(title: t("快速开始", "Quick Start")) {
                    helpRow(t("导入语料", "Import Corpus"), shortcut: "⌘O")
                    helpRow(t("打开设置", "Open Settings"), shortcut: "⌘,")
                    helpRow(t("刷新工作区", "Refresh Workspace"), shortcut: "⌘R")
                    helpRow(t("运行当前页面", "Run Current Page"), shortcut: "主按钮 / Main button")
                }

                WorkbenchPaneCard(title: t("搜索语法", "Search Syntax")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• \(t("普通词：hacker 只匹配 hacker", "Literal term: hacker only matches hacker"))")
                        Text("• \(t("通配：hacker* 可匹配 hacker / hackers", "Wildcard: hacker* can match hacker / hackers"))")
                        Text("• \(t("单字符：hack?r 可匹配 hacker / hackor", "Single character: hack?r can match hacker / hackor"))")
                        Text("• \(t("开启正则后，* 和 ? 将按正则语义处理", "When regex is enabled, * and ? follow regex rules"))")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                WorkbenchPaneCard(title: t("常用流程", "Common Workflows")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. \(t("在语料库里导入并打开语料", "Import and open a corpus from Library"))")
                        Text("2. \(t("在下拉页面菜单里切到统计、词表、KWIC 或 Topics", "Use the page dropdown to switch to Stats, Word, KWIC, or Topics"))")
                        Text("3. \(t("设置检索词或筛选条件后运行当前页面", "Set a query or filters, then run the current page"))")
                        Text("4. \(t("需要表格时用列菜单、排序和导出", "Use columns, sorting, and export when you need a table"))")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                WorkbenchPaneCard(title: t("排查问题", "Troubleshooting"), subtitle: workspace.settings.scene.supportStatus) {
                    if let issue = workspace.issueBanner {
                        WorkbenchIssueBanner(tone: issue.tone, title: issue.title, message: issue.message)
                    }
                    HStack {
                        Button(t("刷新工作区", "Refresh Workspace")) {
                            Task { await workspace.refreshAll() }
                        }
                        Button(t("导出诊断", "Export Diagnostics")) {
                            Task { await workspace.exportDiagnostics() }
                        }
                        if !workspace.settings.scene.userDataDirectory.isEmpty {
                            Button(t("打开数据目录", "Open Data Directory")) {
                                Task { await workspace.openUserDataDirectory() }
                            }
                        }
                    }
                }

                WorkbenchPaneCard(title: t("支持与反馈", "Support & Feedback"), subtitle: workspace.settings.scene.supportStatus) {
                    HStack {
                        Button(t("导出诊断", "Export Diagnostics")) { Task { await workspace.exportDiagnostics() } }
                        Button(t("GitHub 反馈", "GitHub Feedback")) { Task { await workspace.openFeedback() } }
                        Button(t("版本说明", "Release Notes")) { Task { await workspace.openReleaseNotes() } }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private func helpRow(_ title: String, shortcut: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct ReleaseNotesWindowView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WorkbenchHeaderCard(
                    title: t("版本说明", "Release Notes"),
                    subtitle: workspace.settings.scene.latestReleaseTitle.isEmpty
                        ? workspace.settings.scene.latestVersionLabel
                        : workspace.settings.scene.latestReleaseTitle
                ) {
                    Button(t("打开发布页", "Open Release Page")) {
                        Task { await workspace.openReleaseNotes() }
                    }
                }

                WorkbenchPaneCard(title: t("更新状态", "Update Status"), subtitle: workspace.settings.scene.updateSummary) {
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

                WorkbenchPaneCard(title: t("最近更新", "Latest Release"), subtitle: workspace.settings.scene.updateSummary) {
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

                    if workspace.settings.scene.latestReleaseNotes.isEmpty && workspace.settings.scene.releaseNotes.isEmpty {
                        Text(t("当前没有可显示的版本说明。", "No release notes available."))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(t("主要改动", "Highlights"))
                            .font(.headline)
                        ForEach(
                            (workspace.settings.scene.latestReleaseNotes.isEmpty
                             ? workspace.settings.scene.releaseNotes
                             : workspace.settings.scene.latestReleaseNotes),
                            id: \.self
                        ) { line in
                            Text("• \(line)")
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
