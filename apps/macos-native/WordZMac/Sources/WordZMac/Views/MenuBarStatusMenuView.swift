import AppKit
import SwiftUI

struct MenuBarStatusMenuView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var workspace: MainWorkspaceViewModel
    @ObservedObject var sidebar: LibrarySidebarViewModel
    @ObservedObject var settings: WorkspaceSettingsViewModel
    @ObservedObject var taskCenter: NativeTaskCenter

    var body: some View {
        Group {
            Text(currentWorkspaceTitle)
            if !currentCorpusTitle.isEmpty {
                Text(currentCorpusTitle)
            }

            if hasTaskItems {
                Divider()
                Menu(taskMenuTitle) {
                    Text(taskCenter.scene.summary)
                    Button(t("打开任务中心", "Open Task Center")) {
                        openWindowRoute(.taskCenter)
                    }
                    if !taskCenter.scene.highlightedItems.isEmpty {
                        Divider()
                        ForEach(taskCenter.scene.highlightedItems) { item in
                            taskMenuItem(item)
                        }
                    }
                    if taskCenter.scene.completedCount > 0 || taskCenter.scene.failedCount > 0 {
                        Divider()
                        Button(t("清理已完成任务", "Clear Finished Tasks")) {
                            workspace.clearFinishedTasks()
                        }
                    }
                }
            }

            Divider()

            Menu(t("工作区", "Workspace")) {
                Button(windowTitle(.mainWorkspace)) {
                    openMainWorkspace()
                }

                Button(t("导入语料…", "Import Corpora…")) {
                    Task {
                        await workspace.initializeIfNeeded()
                        openWindowRoute(.library)
                        await workspace.importCorpusFromDialog()
                    }
                }

                Button(t("快速预览当前内容", "Quick Look Current Content")) {
                    Task {
                        openMainWorkspace()
                        await workspace.quickLookCurrentCorpus()
                    }
                }
                .disabled(!workspace.canQuickLookCurrentCorpus)

                Button(t("分享当前内容", "Share Current Content")) {
                    Task {
                        openMainWorkspace()
                        await workspace.shareCurrentContent()
                    }
                }
                .disabled(!workspace.canShareCurrentContent)

                if !recentDocuments.isEmpty {
                    Divider()
                    ForEach(recentDocuments.prefix(6)) { item in
                        Button(item.title) {
                            Task {
                                await workspace.initializeIfNeeded()
                                openMainWorkspace()
                                await workspace.openRecentDocument(item.corpusID)
                            }
                        }
                    }
                }
            }

            Menu(t("窗口", "Windows")) {
                windowMenuButton(.library)
                windowMenuButton(.settings)
                windowMenuButton(.taskCenter)
                Divider()
                windowMenuButton(.help)
                windowMenuButton(.releaseNotes)
                windowMenuButton(.about)
            }

            Menu(updateMenuTitle) {
                Text(updateSummaryLine)

                Divider()

                Button(t("检查更新…", "Check for Updates…")) {
                    Task { await workspace.checkForUpdatesNow() }
                }

                if settings.scene.canDownloadUpdate {
                    Button(t("下载更新", "Download Update")) {
                        Task { await workspace.downloadLatestUpdate() }
                    }
                }

                if settings.scene.canInstallDownloadedUpdate {
                    Button(t("安装已下载更新", "Install Downloaded Update")) {
                        Task { await workspace.installDownloadedUpdate() }
                    }
                }
            }

            Divider()

            Button(t("退出 WordZ", "Quit WordZ")) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .task {
            await workspace.initializeIfNeeded()
        }
    }

    private var currentWorkspaceTitle: String {
        let summary = settings.scene.workspaceSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if summary.isEmpty {
            return t("WordZ 菜单栏", "WordZ Menu Bar")
        }
        return t("当前工作区：", "Workspace: ") + summary
    }

    private var currentCorpusTitle: String {
        let corpusName = sidebar.selectedCorpus?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !corpusName.isEmpty else {
            return ""
        }
        return t("当前语料：", "Current Corpus: ") + corpusName
    }

    private var recentDocuments: [RecentDocumentItem] {
        settings.scene.recentDocuments
    }

    private var hasTaskItems: Bool {
        !taskCenter.scene.items.isEmpty
    }

    private var taskMenuTitle: String {
        if taskCenter.scene.runningCount > 0 {
            return t("后台任务", "Background Tasks") + " (\(taskCenter.scene.runningCount))"
        }
        return t("后台任务", "Background Tasks")
    }

    private var updateMenuTitle: String {
        if settings.scene.canInstallDownloadedUpdate {
            return t("更新已下载", "Update Ready")
        }
        if settings.scene.isDownloadingUpdate {
            return t("更新下载中", "Downloading Update")
        }
        if settings.scene.canDownloadUpdate {
            return t("发现新版本", "Update Available")
        }
        if settings.scene.isCheckingUpdates {
            return t("正在检查更新", "Checking for Updates")
        }
        return t("更新状态", "Updates")
    }

    private var updateSummaryLine: String {
        if settings.scene.isDownloadingUpdate, !settings.scene.downloadProgressLabel.isEmpty {
            return settings.scene.downloadProgressLabel
        }
        if !settings.scene.downloadedUpdateName.isEmpty {
            return t("已下载：", "Downloaded: ") + settings.scene.downloadedUpdateName
        }
        if !settings.scene.latestReleaseTitle.isEmpty, settings.scene.canDownloadUpdate {
            return t("可用版本：", "Available: ") + settings.scene.latestReleaseTitle
        }
        return settings.scene.supportStatus
    }

    @ViewBuilder
    private func taskMenuItem(_ item: NativeBackgroundTaskItem) -> some View {
        let title = "\(item.title) · \(item.progressLabel(in: languageMode))"
        if let action = item.primaryAction {
            Button(title) {
                Task { await workspace.performTaskAction(action) }
            }
        } else {
            Text(title)
        }
    }

    private func openMainWorkspace() {
        openWindowRoute(.mainWorkspace)
    }

    private func windowMenuButton(_ route: NativeWindowRoute) -> some View {
        Button(windowTitle(route)) {
            openWindowRoute(route)
        }
    }

    private func windowTitle(_ route: NativeWindowRoute) -> String {
        route.title(in: languageMode)
    }

    private func openWindowRoute(_ route: NativeWindowRoute) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: route.id)
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
