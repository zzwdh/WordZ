import AppKit
import SwiftUI
import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class RootContentSceneTests: XCTestCase {
    func testRootContentSceneBuilderBuildsWindowTitleAndTabs() {
        let scene = RootContentSceneBuilder().build(
            windowTitle: "Demo Corpus",
            activeTab: .kwic,
            languageMode: .chinese
        )

        XCTAssertEqual(scene.windowTitle, "Demo Corpus")
        XCTAssertEqual(scene.selectedTab, .kwic)
        XCTAssertEqual(scene.tabs.map(\.tab), WorkspaceDetailTab.mainWorkspaceTabs)
        XCTAssertEqual(scene.tabs.first(where: { $0.tab == .stats })?.title, "统计")
    }

    func testMainWorkspaceViewModelInitializeSyncsRootScene() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        XCTAssertEqual(workspace.rootScene.windowTitle, "WordZ")
        XCTAssertEqual(workspace.rootScene.selectedTab, .kwic)
        XCTAssertEqual(workspace.rootScene.tabs.count, WorkspaceDetailTab.mainWorkspaceTabs.count)
        XCTAssertFalse(workspace.rootScene.tabs.contains(where: { $0.tab == .library }))
        XCTAssertFalse(workspace.rootScene.tabs.contains(where: { $0.tab == .settings }))
        XCTAssertEqual(workspace.shell.scene.toolbar.items.count, 22)
        XCTAssertEqual(workspace.shell.scene.toolbar.items.first?.action, .refresh)
        XCTAssertEqual(workspace.shell.scene.toolbar.items.first(where: { $0.action == .showLibrary })?.isEnabled, true)
        XCTAssertEqual(workspace.shell.scene.toolbar.items.first(where: { $0.action == .openSelected })?.isEnabled, true)
        XCTAssertEqual(workspace.shell.scene.toolbar.items.first(where: { $0.action == .annotationControls })?.isEnabled, true)
    }

    func testMainWorkspaceCommandContextSharesToolbarSceneModel() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        let context = workspace.commandContext(for: .mainWorkspace)

        XCTAssertTrue(context.supportsWorkspaceCommands)
        XCTAssertEqual(context.toolbar, workspace.shell.scene.toolbar)
        XCTAssertEqual(context.toolbar?.item(for: .refresh)?.action, .refresh)
        XCTAssertEqual(context.toolbar?.item(for: .exportCurrent)?.action, .exportCurrent)
        XCTAssertEqual(context.toolbar?.item(for: workspace.selectedRoute.toolbarRunAction ?? .runKWIC)?.isEnabled, true)
        XCTAssertTrue(context.canRefreshWorkspace)
        XCTAssertEqual(context.selectedMainRoute, workspace.selectedRoute)
        XCTAssertFalse(context.canSelectMainRoute)
        XCTAssertFalse(context.canToggleInspector)
    }

    func testMainWorkspaceCommandContextEnablesSourceViewForProvenanceBackedSelections() async {
        let repository = FakeWorkspaceRepository(
            kwicResult: KWICResult(rows: [
                KWICRow(id: "0-0", left: "", node: "Alpha", right: "beta gamma", sentenceId: 0, sentenceTokenIndex: 0)
            ])
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        XCTAssertFalse(workspace.commandContext(for: .mainWorkspace).canOpenSourceView)

        workspace.kwic.keyword = "alpha"
        await workspace.runKWIC()

        XCTAssertTrue(workspace.commandContext(for: .mainWorkspace).canOpenSourceView)

        workspace.sentiment.apply(makeSentimentResult())
        workspace.sentiment.selectedRowID = "sentiment-positive"
        workspace.selectedTab = .sentiment
        workspace.syncSceneGraph()

        XCTAssertTrue(workspace.commandContext(for: .mainWorkspace).canOpenSourceView)

        workspace.topics.query = "hacker"
        await workspace.runTopics()
        workspace.topics.selectedRowID = "paragraph-1"
        workspace.selectedTab = .topics
        workspace.syncSceneGraph()

        XCTAssertTrue(workspace.commandContext(for: .mainWorkspace).canOpenSourceView)

        workspace.selectedTab = .stats
        workspace.syncSceneGraph()

        XCTAssertFalse(workspace.commandContext(for: .mainWorkspace).canOpenSourceView)
    }

    func testWorkspaceCommandContextsExposeAnnotationControlsOnlyWhereSupported() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        let mainContext = workspace.commandContext(for: .mainWorkspace)
        let sourceReaderContext = workspace.commandContext(for: .sourceReader)
        let libraryContext = workspace.commandContext(for: .library)

        XCTAssertTrue(mainContext.canConfigureAnnotation)
        XCTAssertEqual(mainContext.toolbar?.item(for: .annotationControls)?.isEnabled, true)
        XCTAssertTrue(sourceReaderContext.canConfigureAnnotation)
        XCTAssertFalse(sourceReaderContext.canOpenSourceView)
        XCTAssertFalse(libraryContext.canConfigureAnnotation)
    }

    func testEvidenceWorkbenchCommandContextTracksDossierGroupActions() async {
        let repository = FakeWorkspaceRepository()
        repository.evidenceItems = [
            makeEvidenceItem(
                id: "evidence-intro-1",
                sourceKind: .kwic,
                reviewStatus: .keep,
                sectionTitle: "Intro"
            ),
            makeEvidenceItem(
                id: "evidence-body-1",
                sourceKind: .locator,
                reviewStatus: .keep,
                sectionTitle: "Body"
            ),
            makeEvidenceItem(
                id: "evidence-body-2",
                sourceKind: .plot,
                reviewStatus: .keep,
                sectionTitle: "Body"
            ),
            makeEvidenceItem(
                id: "evidence-conclusion-1",
                sourceKind: .topics,
                reviewStatus: .keep,
                sectionTitle: "Conclusion"
            )
        ]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.refreshEvidenceItems()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section
        workspace.evidenceWorkbench.selectedItemID = "evidence-body-2"

        let splitContext = workspace.commandContext(for: .evidenceWorkbench)
        XCTAssertTrue(splitContext.canMoveEvidenceGroupUp)
        XCTAssertTrue(splitContext.canMoveEvidenceGroupDown)
        XCTAssertTrue(splitContext.canSplitEvidenceGroup)
        XCTAssertTrue(splitContext.canRenameEvidenceGroup)
        XCTAssertTrue(splitContext.canMergeEvidenceGroup)
        XCTAssertTrue(splitContext.canExportEvidenceDossier)
        XCTAssertTrue(splitContext.canExportEvidenceJSON)

        workspace.evidenceWorkbench.selectedItemID = "evidence-body-1"

        let unsplittableContext = workspace.commandContext(for: .evidenceWorkbench)
        XCTAssertTrue(unsplittableContext.canRenameEvidenceGroup)
        XCTAssertTrue(unsplittableContext.canMergeEvidenceGroup)
        XCTAssertFalse(unsplittableContext.canSplitEvidenceGroup)
    }

    func testMainWorkspaceCommandContextAppliesSceneViewMenuState() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        let context = workspace.commandContext(for: .mainWorkspace).applyingViewMenuState(
            selectedMainRoute: workspace.selectedRoute,
            isInspectorPresented: true
        )

        XCTAssertTrue(context.canRefreshWorkspace)
        XCTAssertTrue(context.canSelectMainRoute)
        XCTAssertEqual(context.selectedMainRoute, workspace.selectedRoute)
        XCTAssertTrue(context.canToggleInspector)
        XCTAssertTrue(context.isInspectorPresented)
    }

    func testNonMainWindowCommandContextsDisableViewMenuState() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        for route in [NativeWindowRoute.library, .settings, .help, .sourceReader] {
            let context = workspace.commandContext(for: route)

            XCTAssertFalse(context.canRefreshWorkspace, "Expected refresh to be disabled for \(route.id)")
            XCTAssertFalse(context.canSelectMainRoute, "Expected page switching to be disabled for \(route.id)")
            XCTAssertNil(context.selectedMainRoute, "Expected no selected main route for \(route.id)")
            XCTAssertFalse(context.canToggleInspector, "Expected inspector toggle to be disabled for \(route.id)")
            XCTAssertFalse(context.isInspectorPresented, "Expected inspector to default hidden for \(route.id)")
            XCTAssertFalse(context.canOpenSourceView, "Expected source view action to be disabled for \(route.id)")
        }
    }

    func testMainWorkspaceViewModelTracksTabAndToolbarUpdatesSeparately() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .collocate
        workspace.shell.isBusy = true
        workspace.syncSceneGraph()

        XCTAssertEqual(workspace.rootScene.selectedTab, .collocate)
        XCTAssertEqual(workspace.shell.scene.toolbar.items.first(where: { $0.action == .runStats })?.isEnabled, false)
        XCTAssertEqual(workspace.shell.scene.toolbar.items.first(where: { $0.action == .runCollocate })?.isEnabled, false)
    }

    func testWorkspaceShellFallsBackFromLegacyWordCloudTabToWord() {
        let shell = WorkspaceShellViewModel()

        shell.apply(makeWorkspaceSnapshot(currentTab: "word cloud"))

        XCTAssertEqual(shell.selectedTab, .word)
    }

    func testRootSceneTabsRemainAvailableAfterRunningAnalysis() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.runTokenize()

        XCTAssertFalse(workspace.rootScene.tabs.isEmpty)
        XCTAssertEqual(workspace.rootScene.tabs.map(\.tab), WorkspaceDetailTab.mainWorkspaceTabs)
        XCTAssertEqual(workspace.rootScene.selectedTab, .tokenize)
    }

    func testSettingsSyncSkipsRootSceneRebuildWhenInputsAreUnchanged() async {
        let repository = FakeWorkspaceRepository()
        let builder = CountingRootContentSceneBuilder()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            rootSceneBuilder: builder
        )

        await workspace.initializeIfNeeded()
        let buildCountAfterInitialize = builder.buildCallCount

        workspace.syncSceneGraph(source: .settings)
        workspace.syncSceneGraph(source: .settings)

        XCTAssertEqual(builder.buildCallCount, buildCountAfterInitialize)
    }

    func testNavigationAndResultSyncReuseExistingRootSceneBuildWhenRequestMatches() async {
        let repository = FakeWorkspaceRepository()
        let builder = CountingRootContentSceneBuilder()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            rootSceneBuilder: builder
        )

        await workspace.initializeIfNeeded()
        let buildCountAfterInitialize = builder.buildCallCount

        workspace.selectedTab = .collocate
        XCTAssertEqual(builder.buildCallCount, buildCountAfterInitialize + 1)

        workspace.syncSceneGraph(source: .navigation)
        workspace.syncSceneGraph(source: .resultContent)

        XCTAssertEqual(builder.buildCallCount, buildCountAfterInitialize + 1)
    }

    func testAnalysisRunRebuildsRootSceneOnlyOnceWhenSelectingResultTab() async {
        let repository = FakeWorkspaceRepository()
        let builder = CountingRootContentSceneBuilder()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            rootSceneBuilder: builder
        )

        await workspace.initializeIfNeeded()
        let buildCountAfterInitialize = builder.buildCallCount

        await workspace.runWord()

        XCTAssertEqual(workspace.rootScene.selectedTab, .word)
        XCTAssertEqual(builder.buildCallCount, buildCountAfterInitialize + 1)
    }

    func testRootContentCommandHandlerRoutesWindowCommandsToWindowPresenter() {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())
        var openedRoutes: [String] = []
        var didOpenSettings = false
        let shellHandler = RootContentShellActionHandler(
            workspace: workspace,
            currentSidebarVisibility: { true },
            setSidebarVisibility: { _ in },
            presentWindow: { route in
                openedRoutes.append(route.id)
            }
        )
        let handler = RootContentCommandHandler(
            workspace: workspace,
            shellActionHandler: shellHandler,
            openSettings: {
                didOpenSettings = true
            }
        )

        handler.handle(.showLibrary)
        handler.handle(.showSettings)
        handler.handle(.showHelpWindow)

        XCTAssertTrue(didOpenSettings)
        XCTAssertEqual(openedRoutes, [
            NativeWindowRoute.library.id,
            NativeWindowRoute.help.id
        ])
    }

    func testNativeWindowRoutingPrefersKeyWindowOverRouteFallback() {
        let keyWindow = NSWindow()
        let preferredWindow = NSWindow()
        preferredWindow.identifier = NativeWindowRouting.identifier(for: .library)

        let resolved = NativeWindowRouting.resolvePresentationWindow(
            preferredRoute: .library,
            keyWindow: keyWindow,
            mainWindow: nil,
            fallbackWindows: [preferredWindow]
        )

        XCTAssertTrue(resolved === keyWindow)
    }

    func testNativeWindowRoutingUsesPreferredRouteWhenNoActiveWindowExists() {
        let preferredWindow = NSWindow()
        preferredWindow.identifier = NativeWindowRouting.identifier(for: .library)
        let mainWorkspaceWindow = NSWindow()
        mainWorkspaceWindow.identifier = NativeWindowRouting.identifier(for: .mainWorkspace)

        let resolved = NativeWindowRouting.resolvePresentationWindow(
            preferredRoute: .library,
            keyWindow: nil,
            mainWindow: nil,
            fallbackWindows: [mainWorkspaceWindow, preferredWindow]
        )

        XCTAssertTrue(resolved === preferredWindow)
    }

    func testNativeWindowRoutingFallsBackToMainWorkspaceWindow() {
        let mainWorkspaceWindow = NSWindow()
        mainWorkspaceWindow.identifier = NativeWindowRouting.identifier(for: .mainWorkspace)

        let resolved = NativeWindowRouting.resolvePresentationWindow(
            preferredRoute: .library,
            keyWindow: nil,
            mainWindow: nil,
            fallbackWindows: [mainWorkspaceWindow]
        )

        XCTAssertTrue(resolved === mainWorkspaceWindow)
    }

    func testNativeWindowRoutingRegisterReturnsWindowForRoute() {
        let window = NSWindow()
        NativeWindowRouting.register(window, for: .library)

        XCTAssertTrue(NativeWindowRouting.window(for: .library) === window)

        NativeWindowRouting.register(nil, for: .library)
    }

    func testWorkspaceMainRouteMapsKeywordTab() {
        let route = WorkspaceMainRoute(tab: .keyword)

        XCTAssertEqual(route, .keyword)
        XCTAssertEqual(route.tab, .keyword)
    }

    func testRootContentShellActionHandlerHandlesShellStateChanges() {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())
        var isSidebarVisible = true
        var isInspectorVisible = true
        var openedRoutes: [String] = []
        let handler = RootContentShellActionHandler(
            workspace: workspace,
            currentSidebarVisibility: { isSidebarVisible },
            setSidebarVisibility: { nextValue in
                isSidebarVisible = nextValue
            },
            currentInspectorVisibility: { isInspectorVisible },
            setInspectorVisibility: { nextValue in
                isInspectorVisible = nextValue
            },
            presentWindow: { route in
                openedRoutes.append(route.id)
            }
        )

        handler.handle(.selectTab(.compare))
        handler.handle(.presentWelcome)
        handler.handle(.toggleSidebar)
        handler.handle(.toggleInspector)
        handler.handle(.openWindow(.help))

        XCTAssertEqual(workspace.selectedTab, .compare)
        XCTAssertTrue(workspace.isWelcomePresented)
        XCTAssertFalse(isSidebarVisible)
        XCTAssertFalse(isInspectorVisible)
        XCTAssertEqual(openedRoutes, [NativeWindowRoute.help.id])

        handler.handle(.toggleSidebar)
        handler.handle(.toggleInspector)

        XCTAssertTrue(isSidebarVisible)
        XCTAssertTrue(isInspectorVisible)
    }

    func testRootContentShellActionHandlerSelectRouteUpdatesWorkspaceRoute() {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())
        let handler = RootContentShellActionHandler(
            workspace: workspace,
            currentSidebarVisibility: { true },
            setSidebarVisibility: { _ in },
            presentWindow: { _ in }
        )

        handler.handle(.selectRoute(.compare))

        XCTAssertEqual(workspace.selectedRoute, .compare)
        XCTAssertEqual(workspace.selectedTab, .compare)
    }

    func testMainWorkspaceSplitControllerUpdateAppliesCollapsedStateFromLayout() {
        let controller = MainWorkspaceSplitController(
            sidebar: EmptyView(),
            detail: EmptyView(),
            inspector: EmptyView()
        )

        _ = controller.view
        controller.update(
            sidebar: EmptyView(),
            detail: EmptyView(),
            inspector: EmptyView(),
            layout: WorkspaceSplitLayout(
                isSidebarVisible: false,
                isInspectorVisible: true
            ),
            animateLayoutChanges: false
        )

        XCTAssertTrue(controller.splitViewItems[0].isCollapsed)
        XCTAssertFalse(controller.splitViewItems[2].isCollapsed)

        controller.update(
            sidebar: EmptyView(),
            detail: EmptyView(),
            inspector: EmptyView(),
            layout: WorkspaceSplitLayout(
                isSidebarVisible: true,
                isInspectorVisible: false
            ),
            animateLayoutChanges: false
        )

        XCTAssertFalse(controller.splitViewItems[0].isCollapsed)
        XCTAssertTrue(controller.splitViewItems[2].isCollapsed)
    }

    func testRootContentDefaultLaunchControllerPresentsLibraryWindowOnFirstLaunch() async {
        var hasPresentedWindow = false
        let hostPreferencesStore = InMemoryHostPreferencesStore()
        let workspace = makeMainWorkspaceViewModel(
            repository: FakeWorkspaceRepository(),
            hostPreferencesStore: hostPreferencesStore
        )
        var openedRoutes: [String] = []
        let shellHandler = RootContentShellActionHandler(
            workspace: workspace,
            currentSidebarVisibility: { true },
            setSidebarVisibility: { _ in },
            presentWindow: { route in
                openedRoutes.append(route.id)
            }
        )
        let controller = RootContentDefaultLaunchController(
            hasPresentedWindow: Binding(
                get: { hasPresentedWindow },
                set: { hasPresentedWindow = $0 }
            ),
            workspace: workspace,
            hostPreferencesStore: hostPreferencesStore,
            shellActionHandler: shellHandler
        )
        await workspace.initializeIfNeeded()

        controller.presentLibraryWindowIfNeeded()
        controller.presentLibraryWindowIfNeeded()

        XCTAssertTrue(hasPresentedWindow)
        XCTAssertEqual(openedRoutes, [NativeWindowRoute.library.id])
        XCTAssertTrue(hostPreferencesStore.snapshot.hasCompletedInitialLaunch)
        XCTAssertEqual(hostPreferencesStore.saveCallCount, 1)
    }

    func testRootContentDefaultLaunchControllerSkipsLibraryAfterInitialLaunchWhenLibraryHasContent() async {
        var hasPresentedWindow = false
        let hostPreferencesStore = InMemoryHostPreferencesStore()
        hostPreferencesStore.snapshot.hasCompletedInitialLaunch = true
        let workspace = makeMainWorkspaceViewModel(
            repository: FakeWorkspaceRepository(),
            hostPreferencesStore: hostPreferencesStore
        )
        var openedRoutes: [String] = []
        let shellHandler = RootContentShellActionHandler(
            workspace: workspace,
            currentSidebarVisibility: { true },
            setSidebarVisibility: { _ in },
            presentWindow: { route in
                openedRoutes.append(route.id)
            }
        )
        let controller = RootContentDefaultLaunchController(
            hasPresentedWindow: Binding(
                get: { hasPresentedWindow },
                set: { hasPresentedWindow = $0 }
            ),
            workspace: workspace,
            hostPreferencesStore: hostPreferencesStore,
            shellActionHandler: shellHandler
        )
        await workspace.initializeIfNeeded()

        controller.presentLibraryWindowIfNeeded()

        XCTAssertTrue(hasPresentedWindow)
        XCTAssertTrue(openedRoutes.isEmpty)
        XCTAssertEqual(hostPreferencesStore.saveCallCount, 0)
    }

    func testRootContentDefaultLaunchControllerPresentsLibraryWhenInitialLaunchCompletedButLibraryIsEmpty() async {
        var hasPresentedWindow = false
        let hostPreferencesStore = InMemoryHostPreferencesStore()
        hostPreferencesStore.snapshot.hasCompletedInitialLaunch = true
        let workspace = makeMainWorkspaceViewModel(
            repository: FakeWorkspaceRepository(),
            hostPreferencesStore: hostPreferencesStore
        )
        var openedRoutes: [String] = []
        let shellHandler = RootContentShellActionHandler(
            workspace: workspace,
            currentSidebarVisibility: { true },
            setSidebarVisibility: { _ in },
            presentWindow: { route in
                openedRoutes.append(route.id)
            }
        )
        let controller = RootContentDefaultLaunchController(
            hasPresentedWindow: Binding(
                get: { hasPresentedWindow },
                set: { hasPresentedWindow = $0 }
            ),
            workspace: workspace,
            hostPreferencesStore: hostPreferencesStore,
            shellActionHandler: shellHandler
        )
        await workspace.initializeIfNeeded()
        workspace.sidebar.librarySnapshot = .empty

        controller.presentLibraryWindowIfNeeded()

        XCTAssertTrue(hasPresentedWindow)
        XCTAssertEqual(openedRoutes, [NativeWindowRoute.library.id])
        XCTAssertEqual(hostPreferencesStore.saveCallCount, 0)
    }

    func testNativeWindowRolePolicyKeepsMainWorkspaceRestorableAndMiniaturizable() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        NativeWindowRolePolicy.policy(for: .mainWorkspace).apply(to: window)

        XCTAssertTrue(window.isRestorable)
        XCTAssertTrue(window.styleMask.contains(.miniaturizable))
        XCTAssertEqual(window.tabbingMode, .disallowed)
    }

    func testNativeWindowRolePolicyDisablesRestorationAndMinimizeForUpdateWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        NativeWindowRolePolicy.policy(for: .updatePrompt).apply(to: window)

        XCTAssertFalse(window.isRestorable)
        XCTAssertFalse(window.styleMask.contains(.miniaturizable))
        XCTAssertEqual(window.tabbingMode, .disallowed)
    }

    func testRootContentEventBridgeRoutesCommandNotificationToCommandHandler() {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())
        let delegate = NativeApplicationDelegate()
        let shellHandler = RootContentShellActionHandler(
            workspace: workspace,
            currentSidebarVisibility: { true },
            setSidebarVisibility: { _ in },
            presentWindow: { _ in }
        )
        let bridge = RootContentEventBridge(
            workspace: workspace,
            applicationDelegate: delegate,
            commandHandler: RootContentCommandHandler(
                workspace: workspace,
                shellActionHandler: shellHandler
            )
        )

        bridge.handleCommandNotification(
            Notification(
                name: .wordZMacCommandTriggered,
                object: nil,
                userInfo: ["command": NativeAppCommand.showWelcome.rawValue]
            )
        )

        XCTAssertTrue(workspace.isWelcomePresented)
    }

    func testRootContentEventBridgeEnqueuesIncomingURLPath() {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())
        let delegate = NativeApplicationDelegate()
        let shellHandler = RootContentShellActionHandler(
            workspace: workspace,
            currentSidebarVisibility: { true },
            setSidebarVisibility: { _ in },
            presentWindow: { _ in }
        )
        let bridge = RootContentEventBridge(
            workspace: workspace,
            applicationDelegate: delegate,
            commandHandler: RootContentCommandHandler(
                workspace: workspace,
                shellActionHandler: shellHandler
            )
        )

        bridge.enqueueIncomingURL(URL(fileURLWithPath: "/tmp/demo.txt"))

        XCTAssertEqual(delegate.pendingOpenPaths, ["/tmp/demo.txt"])
    }

    func testRootContentEventBridgeConsumesPendingPaths() {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())
        let delegate = NativeApplicationDelegate()
        let shellHandler = RootContentShellActionHandler(
            workspace: workspace,
            currentSidebarVisibility: { true },
            setSidebarVisibility: { _ in },
            presentWindow: { _ in }
        )
        let bridge = RootContentEventBridge(
            workspace: workspace,
            applicationDelegate: delegate,
            commandHandler: RootContentCommandHandler(
                workspace: workspace,
                shellActionHandler: shellHandler
            )
        )

        delegate.enqueue(paths: ["/tmp/demo.txt"])
        bridge.handlePendingOpenPaths(delegate.pendingOpenPaths)

        XCTAssertTrue(delegate.pendingOpenPaths.isEmpty)
    }

    func testNativeApplicationDelegateQueuesPendingWindowUntilPresenterRegisters() {
        let delegate = NativeApplicationDelegate()
        var openedRoutes: [String] = []

        delegate.presentWindowRoute(.mainWorkspace)
        delegate.registerWindowPresenter { route in
            openedRoutes.append(route.id)
        }

        XCTAssertEqual(openedRoutes, [NativeWindowRoute.mainWorkspace.id])
    }

    func testNativeApplicationDelegateDoesNotAutoPresentMainWorkspaceOnLaunch() {
        let delegate = NativeApplicationDelegate()
        var openedRoutes: [String] = []

        delegate.registerWindowPresenter { route in
            openedRoutes.append(route.id)
        }
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertTrue(openedRoutes.isEmpty)
    }

    func testNativeWindowRoutingRegistersWindowIdentifier() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        NativeWindowRouting.register(window, for: .library)

        XCTAssertEqual(window.identifier?.rawValue, NativeWindowRoute.library.id)
    }
}
