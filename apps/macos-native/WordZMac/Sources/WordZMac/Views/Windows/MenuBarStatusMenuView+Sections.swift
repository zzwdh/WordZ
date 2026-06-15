import AppKit
import SwiftUI

import WordZWindowing
import WordZHost
extension MenuBarStatusMenuView {
    @ViewBuilder
    var workspaceSummarySection: some View {
        Text(currentWorkspaceTitle)
        if !currentCorpusTitle.isEmpty {
            Text(currentCorpusTitle)
        }
    }

    var workspaceMenuSection: some View {
        Menu(t("工作区", "Workspace")) {
            Button(windowTitle(.mainWorkspace)) {
                openMainWorkspace()
            }

            Button(t("导入语料…", "Import Corpora…")) {
                performMenuBarAction("importCorpora", detail: NativeWindowRoute.library.id) {
                    await workspace.initializeIfNeeded()
                    await openWindowRouteAndAwaitActivation(.library)
                    await workspace.importCorpusFromDialog()
                }
            }

            Button(t("快速预览当前内容", "Quick Look Current Content")) {
                performMenuBarAction("quickLookContent", detail: NativeWindowRoute.mainWorkspace.id) {
                    await openWindowRouteAndAwaitActivation(.mainWorkspace)
                    await workspace.performResultArtifactAction(.preview, preferredWindowRoute: .mainWorkspace)
                }
            }
            .disabled(!workspace.canQuickLookCurrentCorpus)

            Button(t("分享当前内容", "Share Current Content")) {
                performMenuBarAction("shareContent", detail: NativeWindowRoute.mainWorkspace.id) {
                    await openWindowRouteAndAwaitActivation(.mainWorkspace)
                    await workspace.performResultArtifactAction(.share, preferredWindowRoute: .mainWorkspace)
                }
            }
            .disabled(!workspace.canShareCurrentContent)

            if !recentDocuments.isEmpty {
                Divider()
                ForEach(recentDocuments.prefix(6)) { item in
                    Button(menuLabel(item.title)) {
                        performMenuBarAction("openRecentDocument", detail: item.corpusID) {
                            await workspace.initializeIfNeeded()
                            await openWindowRouteAndAwaitActivation(.mainWorkspace)
                            await workspace.openRecentDocument(item.corpusID)
                        }
                    }
                }
            }
        }
    }

    var windowMenuSection: some View {
        Menu(t("窗口", "Windows")) {
            windowMenuButton(.library)
            Divider()
            Button(t("设置…", "Settings…")) {
                openSettingsWindow()
            }
            Divider()
            windowMenuButton(.help)
            windowMenuButton(.releaseNotes)
            windowMenuButton(.about)
        }
    }

    var updateMenuSection: some View {
        Menu(updateMenuTitle) {
            Text(updateSummaryLine)

            Divider()

            Button(t("打开更新窗口", "Open Update Window")) {
                openWindowRoute(.updatePrompt)
            }

            Button(t("检查更新…", "Check for Updates…")) {
                performMenuBarAction("checkForUpdates", detail: NativeWindowRoute.updatePrompt.id) {
                    await workspace.checkForUpdatesNow()
                }
            }

            if settings.scene.canDownloadUpdate {
                Button(t("下载更新", "Download Update")) {
                    performMenuBarAction("downloadUpdate", detail: settings.scene.latestAssetName) {
                        await workspace.downloadLatestUpdate()
                    }
                }
            }

            if settings.scene.canInstallDownloadedUpdate {
                Button(t("安装已下载更新", "Install Downloaded Update")) {
                    performMenuBarAction("installDownloadedUpdate", detail: settings.scene.downloadedUpdateName) {
                        await workspace.installDownloadedUpdate()
                    }
                }

                Button(t("在 Finder 中显示已下载更新", "Reveal Downloaded Update in Finder")) {
                    performMenuBarAction("revealDownloadedUpdate", detail: settings.scene.downloadedUpdateName) {
                        await workspace.revealDownloadedUpdate()
                    }
                }
            }
        }
    }

    var quitButton: some View {
        Button(t("退出 WordZ", "Quit WordZ")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }

    var currentWorkspaceTitle: String {
        let summary = settings.scene.workspaceSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if summary.isEmpty {
            return t("WordZ 菜单栏", "WordZ Menu Bar")
        }
        return prefixedMenuLabel("当前工作区：", "Workspace: ", value: summary)
    }

    var currentCorpusTitle: String {
        let corpusName = sidebar.selectedCorpus?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !corpusName.isEmpty else {
            return ""
        }
        return prefixedMenuLabel("当前语料：", "Current Corpus: ", value: corpusName)
    }

    var recentDocuments: [RecentDocumentItem] {
        settings.scene.recentDocuments
    }

    var updateMenuTitle: String {
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

    var updateSummaryLine: String {
        if settings.scene.isDownloadingUpdate, !settings.scene.downloadProgressLabel.isEmpty {
            return menuLabel(settings.scene.downloadProgressLabel)
        }
        if !settings.scene.downloadedUpdateName.isEmpty {
            return prefixedMenuLabel("已下载：", "Downloaded: ", value: settings.scene.downloadedUpdateName)
        }
        if !settings.scene.latestReleaseTitle.isEmpty, settings.scene.canDownloadUpdate {
            return prefixedMenuLabel("可用版本：", "Available: ", value: settings.scene.latestReleaseTitle)
        }
        return menuLabel(settings.scene.supportStatus)
    }
}
