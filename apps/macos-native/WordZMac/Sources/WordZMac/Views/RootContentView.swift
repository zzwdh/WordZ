import SwiftUI

struct RootContentView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var viewModel: MainWorkspaceViewModel
    @StateObject private var dispatcher: WorkspaceActionDispatcher
    @ObservedObject private var applicationDelegate: NativeApplicationDelegate

    init(
        viewModel: MainWorkspaceViewModel,
        applicationDelegate: NativeApplicationDelegate = NativeApplicationDelegate()
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _dispatcher = StateObject(wrappedValue: WorkspaceActionDispatcher(workspace: viewModel))
        _applicationDelegate = ObservedObject(wrappedValue: applicationDelegate)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: viewModel.sidebar,
                onAction: dispatcher.handleSidebarAction
            )
        } detail: {
            VStack(spacing: 0) {
                workspaceHeader
                if let banner = viewModel.issueBanner {
                    issueBannerView(banner)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
                Divider()
                currentDetailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
            .toolbar {
                ToolbarItemGroup {
                    toolbarButton(.showLibrary)
                    toolbarButton(.openSelected)
                    toolbarButton(.runStats)
                    toolbarButton(.runWord)
                    toolbarButton(.runKWIC)
                    toolbarButton(.runCollocate)
                    toolbarButton(.exportCurrent)
                }
                ToolbarItem {
                    Menu(wordZText("更多", "More", mode: languageMode)) {
                        ForEach(secondaryToolbarItems) { item in
                            Button(item.title) {
                                dispatcher.handleToolbarAction(item.action)
                            }
                            .disabled(!item.isEnabled)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.rootScene.windowTitle)
        .background(
            WindowAccessor { window in
                viewModel.attachWindow(window)
            }
        )
        .sheet(isPresented: Binding(
            get: { viewModel.isWelcomePresented },
            set: { viewModel.isWelcomePresented = $0 }
        )) {
            WelcomeSheetView(
                scene: viewModel.welcomeScene,
                onDismiss: { dispatcher.handleWelcomeAction(.dismiss) },
                onOpenSelection: { dispatcher.handleWelcomeAction(.openSelection) },
                onOpenRecent: { dispatcher.handleWelcomeAction(.openRecent($0)) },
                onOpenReleaseNotes: { dispatcher.handleWelcomeAction(.openReleaseNotes) },
                onOpenFeedback: { dispatcher.handleWelcomeAction(.openFeedback) }
            )
        }
        .task {
            await viewModel.initializeIfNeeded()
        }
        .onReceive(applicationDelegate.$pendingOpenPaths) { pendingPaths in
            guard !pendingPaths.isEmpty else { return }
            let paths = applicationDelegate.consumePendingOpenPaths()
            Task { await viewModel.handleExternalPaths(paths) }
        }
        .onOpenURL { url in
            applicationDelegate.enqueue(paths: [url.path])
        }
        .onReceive(NotificationCenter.default.publisher(for: .wordZMacCommandTriggered)) { notification in
            guard let command = NativeAppCommandCenter.parse(notification) else { return }
            handleAppCommand(command)
        }
    }

    private var settingsView: some View {
        SettingsPaneView(
            settings: viewModel.settings,
            onAction: dispatcher.handleSettingsAction
        )
    }

    private var workspaceHeader: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.rootScene.windowTitle)
                            .font(.title2.weight(.semibold))
                        Text(activeStatusLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 16)

                    Text(currentTabTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.rootScene.tabs) { item in
                            Button {
                                viewModel.selectedTab = item.tab
                            } label: {
                                Text(item.title)
                                    .font(.callout.weight(.medium))
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .frame(minWidth: 72)
                                    .background(
                                        viewModel.rootScene.selectedTab == item.tab
                                        ? Color.accentColor.opacity(0.16)
                                        : Color.secondary.opacity(0.07),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private func issueBannerView(_ banner: WorkspaceIssueBanner) -> some View {
        WorkbenchIssueBanner(
            tone: banner.tone,
            title: banner.title,
            message: banner.message
        ) {
            HStack(spacing: 10) {
                if let recoveryAction = banner.recoveryAction {
                    Button(recoveryTitle(for: recoveryAction)) {
                        Task { await performRecoveryAction(recoveryAction) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button(wordZText("帮助中心", "Help Center", mode: languageMode)) {
                    openWindow(id: NativeWindowRoute.help.id)
                }
                Button(wordZText("导出诊断", "Export Diagnostics", mode: languageMode)) {
                    Task { await viewModel.exportDiagnostics() }
                }
                if !viewModel.settings.scene.userDataDirectory.isEmpty {
                    Button(wordZText("打开数据目录", "Open Data Directory", mode: languageMode)) {
                        Task { await viewModel.openUserDataDirectory() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var currentDetailView: some View {
        switch viewModel.rootScene.selectedTab {
        case .library:
            LibraryManagementView(viewModel: viewModel.library, onAction: dispatcher.handleLibraryAction)
        case .stats:
            StatsView(viewModel: viewModel.stats, onAction: dispatcher.handleStatsAction)
        case .word:
            WordView(viewModel: viewModel.word, onAction: dispatcher.handleWordAction)
        case .compare:
            CompareView(viewModel: viewModel.compare, onAction: dispatcher.handleCompareAction)
        case .chiSquare:
            ChiSquareView(viewModel: viewModel.chiSquare, onAction: dispatcher.handleChiSquareAction)
        case .ngram:
            NgramView(viewModel: viewModel.ngram, onAction: dispatcher.handleNgramAction)
        case .wordCloud:
            WordCloudView(viewModel: viewModel.wordCloud, onAction: dispatcher.handleWordCloudAction)
        case .kwic:
            KWICView(viewModel: viewModel.kwic, onAction: dispatcher.handleKWICAction)
        case .collocate:
            CollocateView(viewModel: viewModel.collocate, onAction: dispatcher.handleCollocateAction)
        case .locator:
            LocatorView(viewModel: viewModel.locator, onAction: dispatcher.handleLocatorAction)
        case .settings:
            settingsView
        }
    }

    private func toolbarButton(_ action: WorkspaceToolbarAction) -> some View {
        let item = viewModel.rootScene.toolbar.items.first(where: { $0.action == action })
        return Button(item?.title ?? action.rawValue) {
            dispatcher.handleToolbarAction(action)
        }
        .disabled(item?.isEnabled == false)
        .accessibilityLabel(item?.title ?? action.rawValue)
        .help(item?.title ?? action.rawValue)
    }

    private var secondaryToolbarItems: [WorkspaceToolbarActionItem] {
        viewModel.rootScene.toolbar.items.filter {
            ![WorkspaceToolbarAction.showLibrary,
              .openSelected,
              .runStats,
              .runWord,
              .runKWIC,
              .runCollocate,
              .exportCurrent].contains($0.action)
        }
    }

    private var activeStatusLine: String {
        switch viewModel.rootScene.selectedTab {
        case .library:
            return viewModel.sceneGraph.library.librarySummary
        case .stats:
            return viewModel.sceneGraph.stats.status
        case .word:
            return viewModel.sceneGraph.word.status
        case .compare:
            return viewModel.sceneGraph.compare.status
        case .chiSquare:
            return viewModel.sceneGraph.chiSquare.status
        case .ngram:
            return viewModel.sceneGraph.ngram.status
        case .wordCloud:
            return viewModel.sceneGraph.wordCloud.status
        case .kwic:
            return viewModel.sceneGraph.kwic.status
        case .collocate:
            return viewModel.sceneGraph.collocate.status
        case .locator:
            return viewModel.sceneGraph.locator.status
        case .settings:
            return viewModel.sceneGraph.settings.buildSummary
        }
    }

    private var currentTabTitle: String {
        viewModel.rootScene.tabs.first(where: { $0.tab == viewModel.rootScene.selectedTab })?.title
        ?? viewModel.rootScene.selectedTab.displayTitle
    }

    private func handleAppCommand(_ command: NativeAppCommand) {
        switch command {
        case .importCorpora:
            Task { await viewModel.importCorpusFromDialog() }
        case .newWorkspace:
            Task { await viewModel.newWorkspace() }
        case .restoreWorkspace:
            Task { await viewModel.restoreSavedWorkspace() }
        case .showWelcome:
            viewModel.presentWelcome()
        case .showLibrary:
            viewModel.showLibrary()
        case .showSettings:
            viewModel.showSettings()
        case .showTaskCenterWindow:
            openWindow(id: NativeWindowRoute.taskCenter.id)
        case .showAboutWindow:
            openWindow(id: NativeWindowRoute.about.id)
        case .showHelpWindow:
            openWindow(id: NativeWindowRoute.help.id)
        case .showReleaseNotesWindow:
            openWindow(id: NativeWindowRoute.releaseNotes.id)
        case .refreshWorkspace:
            Task { await viewModel.refreshAll() }
        case .openSelectedCorpus:
            Task { await viewModel.openSelectedCorpus() }
        case .runStats:
            Task { await viewModel.runStats() }
        case .runWord:
            Task { await viewModel.runWord() }
        case .runCompare:
            Task { await viewModel.runCompare() }
        case .runChiSquare:
            Task { await viewModel.runChiSquare() }
        case .runNgram:
            Task { await viewModel.runNgram() }
        case .runWordCloud:
            Task { await viewModel.runWordCloud() }
        case .runKWIC:
            Task { await viewModel.runKWIC() }
        case .runCollocate:
            Task { await viewModel.runCollocate() }
        case .runLocator:
            Task { await viewModel.runLocator() }
        case .exportCurrent:
            Task { await viewModel.exportCurrent() }
        case .checkForUpdates:
            Task { await viewModel.checkForUpdatesNow() }
        case .downloadUpdate:
            Task { await viewModel.downloadLatestUpdate() }
        case .installDownloadedUpdate:
            Task { await viewModel.installDownloadedUpdate() }
        case .exportDiagnostics:
            Task { await viewModel.exportDiagnostics() }
        case .openProjectHome:
            Task { await viewModel.openProjectHome() }
        case .openReleaseNotes:
            Task { await viewModel.openReleaseNotes() }
        case .openFeedback:
            Task { await viewModel.openFeedback() }
        case .clearRecentDocuments:
            Task { await viewModel.clearRecentDocuments() }
        }
    }

    private func recoveryTitle(for action: WorkspaceIssueRecoveryAction) -> String {
        switch action {
        case .refreshWorkspace:
            return wordZText("重试加载", "Retry", mode: languageMode)
        case .checkForUpdates:
            return wordZText("重新检查更新", "Retry Update Check", mode: languageMode)
        case .exportDiagnostics:
            return wordZText("重试导出诊断", "Retry Export", mode: languageMode)
        }
    }

    private func performRecoveryAction(_ action: WorkspaceIssueRecoveryAction) async {
        switch action {
        case .refreshWorkspace:
            await viewModel.refreshAll()
        case .checkForUpdates:
            await viewModel.checkForUpdatesNow()
        case .exportDiagnostics:
            await viewModel.exportDiagnostics()
        }
    }
}
