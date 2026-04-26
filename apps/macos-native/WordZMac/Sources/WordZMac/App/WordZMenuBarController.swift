import AppKit
import Combine
import Foundation

private let menuBarLogger = WordZTelemetry.logger(category: "MenuBar")

@MainActor
protocol WordZMenuBarStatusHosting {
    func insertStatusItem() -> any WordZMenuBarStatusPresenting
    func removeStatusItem(_ item: any WordZMenuBarStatusPresenting)
}

@MainActor
protocol WordZMenuBarStatusPresenting: AnyObject {
    var menu: NSMenu? { get set }
    func setImage(_ image: NSImage, accessibilityLabel: String)
}

@MainActor
struct NativeMenuBarStatusHost: WordZMenuBarStatusHosting {
    func insertStatusItem() -> any WordZMenuBarStatusPresenting {
        NativeMenuBarStatusItem(
            statusItem: NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        )
    }

    func removeStatusItem(_ item: any WordZMenuBarStatusPresenting) {
        guard let nativeItem = item as? NativeMenuBarStatusItem else { return }
        NSStatusBar.system.removeStatusItem(nativeItem.statusItem)
    }
}

@MainActor
final class NativeMenuBarStatusItem: WordZMenuBarStatusPresenting {
    fileprivate let statusItem: NSStatusItem

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    var menu: NSMenu? {
        get { statusItem.menu }
        set { statusItem.menu = newValue }
    }

    func setImage(_ image: NSImage, accessibilityLabel: String) {
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = accessibilityLabel
    }
}

@MainActor
package final class WordZMenuBarController: NSObject, ObservableObject, NSMenuDelegate {
    private enum MenuAction {
        case openWindow(NativeWindowRoute)
        case openSettings
        case importCorpora
        case quickLookCurrentContent
        case shareCurrentContent
        case openRecentDocument(String)
        case taskAction(NativeBackgroundTaskAction)
        case clearFinishedTasks
        case checkForUpdates
        case downloadUpdate
        case installDownloadedUpdate
        case revealDownloadedUpdate
        case quit
    }

    private let workspace: MainWorkspaceViewModel
    private let localization: WordZLocalization
    private let statusHost: any WordZMenuBarStatusHosting
    private var applicationDelegate: NativeApplicationDelegate?
    private var statusItem: (any WordZMenuBarStatusPresenting)?
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false

    init(
        workspace: MainWorkspaceViewModel,
        localization: WordZLocalization = .shared,
        statusHost: any WordZMenuBarStatusHosting = NativeMenuBarStatusHost()
    ) {
        self.workspace = workspace
        self.localization = localization
        self.statusHost = statusHost
    }

    package convenience init(
        workspace: MainWorkspaceViewModel,
        localization: WordZLocalization = .shared
    ) {
        self.init(
            workspace: workspace,
            localization: localization,
            statusHost: NativeMenuBarStatusHost()
        )
    }

    var isStatusItemInserted: Bool {
        statusItem != nil
    }

    package func start(applicationDelegate: NativeApplicationDelegate) {
        self.applicationDelegate = applicationDelegate

        guard !hasStarted else {
            syncStatusItemVisibility()
            return
        }

        hasStarted = true

        workspace.settings.$showMenuBarIcon
            .removeDuplicates()
            .sink { [weak self] isVisible in
                self?.applyStatusItemVisibility(isVisible)
            }
            .store(in: &cancellables)

        workspace.menuBarStatus.$iconState
            .removeDuplicates()
            .sink { [weak self] iconState in
                self?.syncStatusItemImage(iconState)
            }
            .store(in: &cancellables)

        syncStatusItemVisibility()
    }

    func rebuildMenu() {
        guard let menu = statusItem?.menu else { return }
        populate(menu)
    }

    package func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }

    private func syncStatusItemVisibility() {
        applyStatusItemVisibility(workspace.settings.showMenuBarIcon)
    }

    private func applyStatusItemVisibility(_ isVisible: Bool) {
        if isVisible {
            insertStatusItemIfNeeded()
        } else {
            removeStatusItemIfNeeded()
        }
    }

    private func insertStatusItemIfNeeded() {
        guard statusItem == nil else {
            syncStatusItemImage()
            rebuildMenu()
            return
        }

        let insertedItem = statusHost.insertStatusItem()
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        insertedItem.menu = menu
        statusItem = insertedItem

        syncStatusItemImage(workspace.menuBarStatus.iconState)
        rebuildMenu()
        logMenuBarAction("insertStatusItem")
    }

    private func removeStatusItemIfNeeded() {
        guard let statusItem else { return }
        statusHost.removeStatusItem(statusItem)
        self.statusItem = nil
        logMenuBarAction("removeStatusItem")
    }

    private func syncStatusItemImage() {
        syncStatusItemImage(workspace.menuBarStatus.iconState)
    }

    private func syncStatusItemImage(_ iconState: WordZMenuBarIconState) {
        guard let statusItem else { return }
        statusItem.setImage(
            WordZMenuBarIcon.image(state: iconState),
            accessibilityLabel: "WordZ"
        )
    }

    private func populate(_ menu: NSMenu) {
        let snapshot = makeSnapshot()

        menu.removeAllItems()
        menu.addItem(disabledLabelItem(snapshot.currentWorkspaceTitle))
        if !snapshot.currentCorpusTitle.isEmpty {
            menu.addItem(disabledLabelItem(snapshot.currentCorpusTitle))
        }

        if snapshot.hasTaskItems {
            menu.addItem(.separator())
            menu.addItem(
                submenuItem(
                    snapshot.taskMenuTitle,
                    submenu: makeTaskMenu(snapshot: snapshot)
                )
            )
        }

        menu.addItem(.separator())
        menu.addItem(
            submenuItem(
                t("工作区", "Workspace"),
                submenu: makeWorkspaceMenu(snapshot: snapshot)
            )
        )
        menu.addItem(
            submenuItem(
                t("窗口", "Windows"),
                submenu: makeWindowMenu()
            )
        )
        menu.addItem(
            submenuItem(
                snapshot.updateMenuTitle,
                submenu: makeUpdateMenu(snapshot: snapshot)
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            actionItem(
                t("退出 WordZ", "Quit WordZ"),
                action: .quit,
                keyEquivalent: "q",
                modifierMask: [.command]
            )
        )
    }

    private func makeTaskMenu(snapshot: WordZMenuBarSnapshot) -> NSMenu {
        let menu = configuredSubmenu()
        menu.addItem(disabledLabelItem(menuLabel(workspace.taskCenter.scene.summary)))
        menu.addItem(
            actionItem(
                t("打开任务中心", "Open Task Center"),
                action: .openWindow(.taskCenter)
            )
        )

        if !workspace.taskCenter.scene.highlightedItems.isEmpty {
            menu.addItem(.separator())
            for item in workspace.taskCenter.scene.highlightedItems {
                let title = menuLabel("\(item.title) · \(item.progressLabel(in: localization.effectiveMode))")
                if let action = item.primaryAction {
                    menu.addItem(actionItem(title, action: .taskAction(action)))
                } else {
                    menu.addItem(disabledLabelItem(title))
                }
            }
        }

        if workspace.taskCenter.scene.completedCount > 0 || workspace.taskCenter.scene.failedCount > 0 {
            menu.addItem(.separator())
            menu.addItem(
                actionItem(
                    t("清理已完成任务", "Clear Finished Tasks"),
                    action: .clearFinishedTasks
                )
            )
        }

        return menu
    }

    private func makeWorkspaceMenu(snapshot: WordZMenuBarSnapshot) -> NSMenu {
        let menu = configuredSubmenu()

        menu.addItem(
            actionItem(
                windowTitle(.mainWorkspace),
                action: .openWindow(.mainWorkspace)
            )
        )
        menu.addItem(
            actionItem(
                t("导入语料…", "Import Corpora…"),
                action: .importCorpora
            )
        )
        menu.addItem(
            actionItem(
                t("快速预览当前内容", "Quick Look Current Content"),
                action: .quickLookCurrentContent,
                isEnabled: workspace.canQuickLookCurrentCorpus
            )
        )
        menu.addItem(
            actionItem(
                t("分享当前内容", "Share Current Content"),
                action: .shareCurrentContent,
                isEnabled: workspace.canShareCurrentContent
            )
        )

        if !snapshot.recentDocuments.isEmpty {
            menu.addItem(.separator())
            for item in snapshot.recentDocuments.prefix(6) {
                menu.addItem(
                    actionItem(
                        menuLabel(item.title),
                        action: .openRecentDocument(item.corpusID)
                    )
                )
            }
        }

        return menu
    }

    private func makeWindowMenu() -> NSMenu {
        let menu = configuredSubmenu()

        menu.addItem(
            actionItem(
                windowTitle(.library),
                action: .openWindow(.library)
            )
        )
        menu.addItem(
            actionItem(
                windowTitle(.taskCenter),
                action: .openWindow(.taskCenter)
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            actionItem(
                t("设置…", "Settings…"),
                action: .openSettings
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            actionItem(
                windowTitle(.help),
                action: .openWindow(.help)
            )
        )
        menu.addItem(
            actionItem(
                windowTitle(.releaseNotes),
                action: .openWindow(.releaseNotes)
            )
        )
        menu.addItem(
            actionItem(
                windowTitle(.about),
                action: .openWindow(.about)
            )
        )

        return menu
    }

    private func makeUpdateMenu(snapshot: WordZMenuBarSnapshot) -> NSMenu {
        let menu = configuredSubmenu()

        menu.addItem(disabledLabelItem(snapshot.updateSummaryLine))
        menu.addItem(.separator())
        menu.addItem(
            actionItem(
                t("打开更新窗口", "Open Update Window"),
                action: .openWindow(.updatePrompt)
            )
        )
        menu.addItem(
            actionItem(
                t("检查更新…", "Check for Updates…"),
                action: .checkForUpdates
            )
        )

        if workspace.settings.scene.canDownloadUpdate {
            menu.addItem(
                actionItem(
                    t("下载更新", "Download Update"),
                    action: .downloadUpdate
                )
            )
        }

        if workspace.settings.scene.canInstallDownloadedUpdate {
            menu.addItem(
                actionItem(
                    t("安装已下载更新", "Install Downloaded Update"),
                    action: .installDownloadedUpdate
                )
            )
            menu.addItem(
                actionItem(
                    t("在 Finder 中显示已下载更新", "Reveal Downloaded Update in Finder"),
                    action: .revealDownloadedUpdate
                )
            )
        }

        return menu
    }

    private func configuredSubmenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        return menu
    }

    private func actionItem(
        _ title: String,
        action: MenuAction,
        isEnabled: Bool = true,
        keyEquivalent: String = "",
        modifierMask: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: #selector(handleMenuItemAction(_:)),
            keyEquivalent: keyEquivalent
        )
        item.target = self
        item.representedObject = action
        item.isEnabled = isEnabled
        item.keyEquivalentModifierMask = modifierMask
        return item
    }

    private func disabledLabelItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func submenuItem(_ title: String, submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    @objc
    private func handleMenuItemAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? MenuAction else { return }
        handle(action)
    }

    private func handle(_ action: MenuAction) {
        switch action {
        case .openWindow(let route):
            logMenuBarAction("openWindow", detail: route.id)
            openWindowRoute(route)
        case .openSettings:
            logMenuBarAction("openSettings", detail: NativeWindowRoute.settings.id)
            NativeSettingsSupport.openSettingsWindow()
        case .importCorpora:
            performMenuBarAction("importCorpora", detail: NativeWindowRoute.library.id) {
                await self.openWindowRouteAndAwaitActivation(.library)
                await self.workspace.importCorpusFromDialog(preferredWindowRoute: .library)
            }
        case .quickLookCurrentContent:
            performMenuBarAction("quickLookContent", detail: NativeWindowRoute.mainWorkspace.id) {
                await self.openWindowRouteAndAwaitActivation(.mainWorkspace)
                await self.workspace.quickLookCurrentCorpus()
            }
        case .shareCurrentContent:
            performMenuBarAction("shareContent", detail: NativeWindowRoute.mainWorkspace.id) {
                await self.openWindowRouteAndAwaitActivation(.mainWorkspace)
                await self.workspace.shareCurrentContent()
            }
        case .openRecentDocument(let corpusID):
            performMenuBarAction("openRecentDocument", detail: corpusID) {
                await self.openWindowRouteAndAwaitActivation(.mainWorkspace)
                await self.workspace.openRecentDocument(corpusID)
            }
        case .taskAction(let action):
            performMenuBarAction("taskAction", detail: action.title(in: localization.effectiveMode)) {
                await self.workspace.performTaskAction(action)
            }
        case .clearFinishedTasks:
            logMenuBarAction("clearFinishedTasks")
            workspace.clearFinishedTasks()
        case .checkForUpdates:
            performMenuBarAction("checkForUpdates") {
                await self.workspace.checkForUpdatesNow()
            }
        case .downloadUpdate:
            performMenuBarAction("downloadUpdate", detail: workspace.settings.scene.latestAssetName) {
                await self.workspace.downloadLatestUpdate()
            }
        case .installDownloadedUpdate:
            performMenuBarAction("installDownloadedUpdate", detail: workspace.settings.scene.downloadedUpdateName) {
                await self.workspace.installDownloadedUpdate()
            }
        case .revealDownloadedUpdate:
            performMenuBarAction("revealDownloadedUpdate", detail: workspace.settings.scene.downloadedUpdateName) {
                await self.workspace.revealDownloadedUpdate()
            }
        case .quit:
            logMenuBarAction("quit")
            NSApp.terminate(nil)
        }
    }

    private func performMenuBarAction(
        _ action: String,
        detail: String = "",
        operation: @escaping @MainActor () async -> Void
    ) {
        logMenuBarAction(action, detail: detail)
        Task { @MainActor in
            await workspace.initializeIfNeeded()
            await operation()
        }
    }

    private func openWindowRoute(_ route: NativeWindowRoute) {
        applicationDelegate?.presentWindowRoute(route)
    }

    private func openWindowRouteAndAwaitActivation(_ route: NativeWindowRoute) async {
        openWindowRoute(route)
        _ = await NativeWindowRouting.waitUntilActive(route)
    }

    private func makeSnapshot() -> WordZMenuBarSnapshot {
        WordZMenuBarSnapshot(
            settingsScene: workspace.settings.scene,
            selectedCorpus: workspace.sidebar.selectedCorpus,
            taskCenterScene: workspace.taskCenter.scene,
            languageMode: localization.effectiveMode
        )
    }

    private func windowTitle(_ route: NativeWindowRoute) -> String {
        route.title(in: localization.effectiveMode)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: localization.effectiveMode)
    }

    private func menuLabel(_ text: String) -> String {
        WordZMenuBarTextSupport.menuLabel(text)
    }

    private func logMenuBarAction(_ action: String, detail: String = "") {
        if detail.isEmpty {
            menuBarLogger.info("action=\(action, privacy: .public)")
        } else {
            menuBarLogger.info("action=\(action, privacy: .public) detail=\(detail, privacy: .public)")
        }
    }
}

private struct WordZMenuBarSnapshot {
    let currentWorkspaceTitle: String
    let currentCorpusTitle: String
    let recentDocuments: [RecentDocumentItem]
    let hasTaskItems: Bool
    let taskMenuTitle: String
    let updateMenuTitle: String
    let updateSummaryLine: String

    init(
        settingsScene: SettingsPaneSceneModel,
        selectedCorpus: LibraryCorpusItem?,
        taskCenterScene: NativeTaskCenterSceneModel,
        languageMode: AppLanguageMode
    ) {
        let workspaceSummary = settingsScene.workspaceSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if workspaceSummary.isEmpty {
            self.currentWorkspaceTitle = wordZText("WordZ 菜单栏", "WordZ Menu Bar", mode: languageMode)
        } else {
            self.currentWorkspaceTitle = WordZMenuBarTextSupport.menuLabel(
                wordZText("当前工作区：", "Workspace: ", mode: languageMode) + workspaceSummary
            )
        }

        let corpusName = selectedCorpus?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if corpusName.isEmpty {
            self.currentCorpusTitle = ""
        } else {
            self.currentCorpusTitle = WordZMenuBarTextSupport.menuLabel(
                wordZText("当前语料：", "Current Corpus: ", mode: languageMode) + corpusName
            )
        }

        self.recentDocuments = settingsScene.recentDocuments
        self.hasTaskItems = !taskCenterScene.items.isEmpty

        if taskCenterScene.runningCount > 0 {
            self.taskMenuTitle = wordZText("后台任务", "Background Tasks", mode: languageMode) + " (\(taskCenterScene.runningCount))"
        } else {
            self.taskMenuTitle = wordZText("后台任务", "Background Tasks", mode: languageMode)
        }

        if settingsScene.canInstallDownloadedUpdate {
            self.updateMenuTitle = wordZText("更新已下载", "Update Ready", mode: languageMode)
        } else if settingsScene.isDownloadingUpdate {
            self.updateMenuTitle = wordZText("更新下载中", "Downloading Update", mode: languageMode)
        } else if settingsScene.canDownloadUpdate {
            self.updateMenuTitle = wordZText("发现新版本", "Update Available", mode: languageMode)
        } else if settingsScene.isCheckingUpdates {
            self.updateMenuTitle = wordZText("正在检查更新", "Checking for Updates", mode: languageMode)
        } else {
            self.updateMenuTitle = wordZText("更新状态", "Updates", mode: languageMode)
        }

        if settingsScene.isDownloadingUpdate, !settingsScene.downloadProgressLabel.isEmpty {
            self.updateSummaryLine = WordZMenuBarTextSupport.menuLabel(settingsScene.downloadProgressLabel)
        } else if !settingsScene.downloadedUpdateName.isEmpty {
            self.updateSummaryLine = WordZMenuBarTextSupport.menuLabel(
                wordZText("已下载：", "Downloaded: ", mode: languageMode) + settingsScene.downloadedUpdateName
            )
        } else if !settingsScene.latestReleaseTitle.isEmpty, settingsScene.canDownloadUpdate {
            self.updateSummaryLine = WordZMenuBarTextSupport.menuLabel(
                wordZText("可用版本：", "Available: ", mode: languageMode) + settingsScene.latestReleaseTitle
            )
        } else {
            self.updateSummaryLine = WordZMenuBarTextSupport.menuLabel(settingsScene.supportStatus)
        }
    }
}
