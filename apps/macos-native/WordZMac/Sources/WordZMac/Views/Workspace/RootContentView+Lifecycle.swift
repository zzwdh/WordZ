import AppKit
import SwiftUI

@MainActor
struct RootContentLifecycleController {
    let workspace: MainWorkspaceViewModel

    func initializeIfNeeded() async {
        await workspace.initializeIfNeeded()
    }

    func attachWindow(_ window: NSWindow?) {
        workspace.windowDocumentController.attach(window: window)
        workspace.flowCoordinator.syncWindowDocumentState(features: workspace.features)
    }
}

@MainActor
struct RootContentWelcomeController {
    let workspace: MainWorkspaceViewModel
    let dispatcher: WorkspaceActionDispatcher
    let shellActionHandler: any RootContentShellActionHandling

    var isPresented: Binding<Bool> {
        Binding(
            get: { workspace.isWelcomePresented },
            set: { isPresented in
                shellActionHandler.handle(isPresented ? .presentWelcome : .dismissWelcome)
            }
        )
    }

    @ViewBuilder
    var sheet: some View {
        WelcomeSheetView(
            scene: workspace.welcomeScene,
            onDismiss: { dispatcher.handleWelcomeAction(.dismiss) },
            onOpenSelection: { dispatcher.handleWelcomeAction(.openSelection) },
            onOpenRecent: { dispatcher.handleWelcomeAction(.openRecent($0)) },
            onOpenReleaseNotes: { dispatcher.handleWelcomeAction(.openReleaseNotes) },
            onOpenFeedback: { dispatcher.handleWelcomeAction(.openFeedback) }
        )
    }
}

@MainActor
struct RootContentEventBridge {
    let workspace: MainWorkspaceViewModel
    let applicationDelegate: NativeApplicationDelegate
    let commandHandler: RootContentCommandHandler

    func handlePendingOpenPaths(_ pendingPaths: [String]) {
        guard !pendingPaths.isEmpty else { return }
        let paths = applicationDelegate.consumePendingOpenPaths()
        guard !paths.isEmpty else { return }
        Task { await workspace.handleExternalPaths(paths) }
    }

    func enqueueIncomingURL(_ url: URL) {
        applicationDelegate.enqueue(paths: [url.path])
    }

    func handleCommandNotification(_ notification: Notification) {
        guard let command = NativeAppCommandCenter.parse(notification) else { return }
        commandHandler.handle(command)
    }
}

struct RootContentShellLifecycleModifier: ViewModifier {
    let lifecycle: RootContentLifecycleController
    let welcomeController: RootContentWelcomeController
    let eventBridge: RootContentEventBridge
    let commandHandler: RootContentCommandHandler
    let shellActionHandler: any RootContentShellActionHandling
    let applicationDelegate: NativeApplicationDelegate
    let defaultLaunchController: RootContentDefaultLaunchController
    let presentWindow: (NativeWindowRoute) -> Void
    let windowTitleProvider: (AppLanguageMode) -> String

    func body(content: Content) -> some View {
        content
            .bindWindowRoute(.mainWorkspace, titleProvider: windowTitleProvider) { window in
                lifecycle.attachWindow(window)
            }
            .sheet(isPresented: welcomeController.isPresented) {
                welcomeController.sheet
            }
            .task {
                applicationDelegate.registerWindowPresenter(presentWindow)
                await lifecycle.initializeIfNeeded()
                defaultLaunchController.presentLibraryWindowIfNeeded()
            }
            .onReceive(applicationDelegate.$pendingOpenPaths, perform: eventBridge.handlePendingOpenPaths)
            .onOpenURL(perform: eventBridge.enqueueIncomingURL)
            .onReceive(NotificationCenter.default.publisher(for: .wordZMacCommandTriggered), perform: eventBridge.handleCommandNotification)
    }
}

extension RootContentView {
    var lifecycleController: RootContentLifecycleController {
        RootContentLifecycleController(workspace: viewModel)
    }

    var welcomeController: RootContentWelcomeController {
        RootContentWelcomeController(
            workspace: viewModel,
            dispatcher: dispatcher,
            shellActionHandler: shellActionHandler
        )
    }

    var eventBridge: RootContentEventBridge {
        RootContentEventBridge(
            workspace: viewModel,
            applicationDelegate: applicationDelegate,
            commandHandler: commandHandler
        )
    }

    var shellLifecycleModifier: RootContentShellLifecycleModifier {
        RootContentShellLifecycleModifier(
            lifecycle: lifecycleController,
            welcomeController: welcomeController,
            eventBridge: eventBridge,
            commandHandler: commandHandler,
            shellActionHandler: shellActionHandler,
            applicationDelegate: applicationDelegate,
            defaultLaunchController: RootContentDefaultLaunchController(
                hasPresentedWindow: $hasPresentedDefaultLaunchWindow,
                workspace: viewModel,
                hostPreferencesStore: viewModel.hostPreferencesStore,
                shellActionHandler: shellActionHandler
            ),
            presentWindow: { route in
                openWindow(id: route.id)
            },
            windowTitleProvider: { _ in
                viewModel.windowTitle
            }
        )
    }
}
