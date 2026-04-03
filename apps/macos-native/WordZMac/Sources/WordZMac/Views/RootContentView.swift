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
        VStack(spacing: 0) {
            workspaceChrome
            currentDetailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup {
                toolbarButton(.refresh)
                toolbarButton(.openSelected)
                toolbarButton(.exportCurrent)
            }
            if !secondaryToolbarItems.isEmpty {
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

    private var workspaceChrome: some View {
        VStack(spacing: 0) {
            workspaceHeader
            if let banner = viewModel.issueBanner {
                issueBannerView(banner)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            if viewModel.taskCenter.scene.runningCount > 0 {
                taskProgressPreview
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            Divider()
        }
        .background(.ultraThinMaterial)
    }

    private var workspaceHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.rootScene.tabs) { item in
                    workspaceTabButton(item)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minHeight: 56)
    }

    private var taskProgressPreview: some View {
        WorkbenchTaskPreviewStrip(scene: viewModel.taskCenter.scene)
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
                Button(wordZText("使用说明", "Usage Guide", mode: languageMode)) {
                    openWindow(id: NativeWindowRoute.help.id)
                }
                Button(wordZText("导出诊断包", "Export Diagnostics Bundle", mode: languageMode)) {
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
        case .library, .settings, .stats:
            StatsView(viewModel: viewModel.stats, onAction: dispatcher.handleStatsAction)
        case .word:
            WordView(viewModel: viewModel.word, onAction: dispatcher.handleWordAction)
        case .tokenize:
            TokenizeView(viewModel: viewModel.tokenize, onAction: dispatcher.handleTokenizeAction)
        case .topics:
            TopicsView(viewModel: viewModel.topics, onAction: dispatcher.handleTopicsAction)
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
            ![WorkspaceToolbarAction.refresh,
              .openSelected,
              .showLibrary,
              .runStats,
              .runWord,
              .runTokenize,
              .runTopics,
              .runCompare,
              .runChiSquare,
              .runNgram,
              .runWordCloud,
              .runKWIC,
              .runCollocate,
              .runLocator,
              .exportCurrent].contains($0.action)
        }
    }

    private func workspaceTabButton(_ item: RootContentTabSceneItem) -> some View {
        let resolvedSelectedTab = viewModel.rootScene.selectedTab
        let isSelected = item.tab == resolvedSelectedTab
        return Button {
            viewModel.selectedTab = item.tab
        } label: {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? AnyShapeStyle(Color.blue.gradient)
                    : AnyShapeStyle(Color.blue.opacity(0.12))
                , in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func handleAppCommand(_ command: NativeAppCommand) {
        switch command {
        case .importCorpora:
            openWindow(id: NativeWindowRoute.library.id)
            Task { await viewModel.importCorpusFromDialog() }
        case .newWorkspace:
            Task { await viewModel.newWorkspace() }
        case .restoreWorkspace:
            Task { await viewModel.restoreSavedWorkspace() }
        case .showWelcome:
            viewModel.presentWelcome()
        case .showLibrary:
            openWindow(id: NativeWindowRoute.library.id)
        case .showSettings:
            openWindow(id: NativeWindowRoute.settings.id)
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
        case .quickLookCurrentCorpus:
            Task { await viewModel.quickLookCurrentCorpus() }
        case .shareCurrentContent:
            Task { await viewModel.shareCurrentContent() }
        case .runStats:
            Task { await viewModel.runStats() }
        case .runWord:
            Task { await viewModel.runWord() }
        case .runTokenize:
            Task { await viewModel.runTokenize() }
        case .runTopics:
            Task { await viewModel.runTopics() }
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
            return wordZText("重试导出诊断包", "Retry Export Diagnostics Bundle", mode: languageMode)
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
