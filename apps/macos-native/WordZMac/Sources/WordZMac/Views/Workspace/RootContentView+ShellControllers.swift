import Foundation
import SwiftUI

struct WorkspaceWindowLayoutState: DynamicProperty {
    @SceneStorage("wordz.workspace.sidebarVisible") private var isSidebarVisible = true
    @SceneStorage("wordz.workspace.inspectorVisible") private var isInspectorVisible = true

    var sidebarVisibility: Bool {
        isSidebarVisible
    }

    var inspectorVisibility: Bool {
        isInspectorVisible
    }

    var sidebarVisibilityBinding: Binding<Bool> {
        $isSidebarVisible
    }

    var inspectorVisibilityBinding: Binding<Bool> {
        $isInspectorVisible
    }
}

@MainActor
struct RootContentDefaultLaunchController {
    let hasPresentedWindow: Binding<Bool>
    let workspace: MainWorkspaceViewModel
    let hostPreferencesStore: any NativeHostPreferencesStoring
    let shellActionHandler: any RootContentShellActionHandling

    func presentLibraryWindowIfNeeded() {
        guard !hasPresentedWindow.wrappedValue else { return }
        hasPresentedWindow.wrappedValue = true

        let snapshot = hostPreferencesStore.load()
        let shouldPresentLibrary = !snapshot.hasCompletedInitialLaunch || workspace.sidebar.librarySnapshot.corpora.isEmpty
        if !snapshot.hasCompletedInitialLaunch {
            do {
                var updatedSnapshot = snapshot
                updatedSnapshot.hasCompletedInitialLaunch = true
                try hostPreferencesStore.save(updatedSnapshot)
            } catch {
                workspace.settings.setSupportStatus(error.localizedDescription)
            }
        }

        guard shouldPresentLibrary else { return }
        shellActionHandler.handle(.openWindow(.library))
    }
}

enum RootContentShellAction {
    case selectTab(WorkspaceDetailTab)
    case selectRoute(WorkspaceMainRoute)
    case setSidebarVisible(Bool)
    case setInspectorVisible(Bool)
    case toggleSidebar
    case toggleInspector
    case presentWelcome
    case dismissWelcome
    case openWindow(NativeWindowRoute)
}

@MainActor
protocol RootContentShellActionHandling {
    func handle(_ action: RootContentShellAction)
}

@MainActor
struct RootContentShellActionHandler: RootContentShellActionHandling {
    let workspace: MainWorkspaceViewModel
    let currentSidebarVisibility: () -> Bool
    let setSidebarVisibility: (Bool) -> Void
    let currentInspectorVisibility: () -> Bool
    let setInspectorVisibility: (Bool) -> Void
    let presentWindow: (NativeWindowRoute) -> Void

    init(
        workspace: MainWorkspaceViewModel,
        currentSidebarVisibility: @escaping () -> Bool,
        setSidebarVisibility: @escaping (Bool) -> Void,
        currentInspectorVisibility: @escaping () -> Bool = { true },
        setInspectorVisibility: @escaping (Bool) -> Void = { _ in },
        presentWindow: @escaping (NativeWindowRoute) -> Void
    ) {
        self.workspace = workspace
        self.currentSidebarVisibility = currentSidebarVisibility
        self.setSidebarVisibility = setSidebarVisibility
        self.currentInspectorVisibility = currentInspectorVisibility
        self.setInspectorVisibility = setInspectorVisibility
        self.presentWindow = presentWindow
    }

    func handle(_ action: RootContentShellAction) {
        switch action {
        case .selectTab(let tab):
            workspace.selectedTab = tab
        case .selectRoute(let route):
            workspace.selectedRoute = route
        case .setSidebarVisible(let isVisible):
            setSidebarVisibility(isVisible)
        case .setInspectorVisible(let isVisible):
            setInspectorVisibility(isVisible)
        case .toggleSidebar:
            setSidebarVisibility(!currentSidebarVisibility())
        case .toggleInspector:
            setInspectorVisibility(!currentInspectorVisibility())
        case .presentWelcome:
            workspace.presentWelcome()
        case .dismissWelcome:
            workspace.dismissWelcome()
        case .openWindow(let route):
            presentWindow(route)
        }
    }
}

extension RootContentView {
    var mainWorkspaceCommandContext: WorkspaceCommandContext {
        viewModel
            .commandContext(for: .mainWorkspace)
            .applyingViewMenuState(
                selectedMainRoute: viewModel.selectedRoute,
                isInspectorPresented: isInspectorVisible
            )
    }

    var isSidebarVisible: Bool {
        layoutState.sidebarVisibility
    }

    var isInspectorVisible: Bool {
        layoutState.inspectorVisibility
    }

    var shellActionHandler: any RootContentShellActionHandling {
        RootContentShellActionHandler(
            workspace: viewModel,
            currentSidebarVisibility: { layoutState.sidebarVisibility },
            setSidebarVisibility: { nextValue in
                layoutState.sidebarVisibilityBinding.wrappedValue = nextValue
            },
            currentInspectorVisibility: { layoutState.inspectorVisibility },
            setInspectorVisibility: { nextValue in
                layoutState.inspectorVisibilityBinding.wrappedValue = nextValue
            },
            presentWindow: { route in
                openWindow(id: route.id)
            }
        )
    }
}
