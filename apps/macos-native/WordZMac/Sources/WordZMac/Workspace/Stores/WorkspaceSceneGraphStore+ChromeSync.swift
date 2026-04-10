import Foundation

@MainActor
extension WorkspaceSceneGraphStore {
    func syncShellNavigation(shell: WorkspaceShellSceneModel, activeTab: WorkspaceDetailTab) {
        updateGraph(shell: shell, activeTab: activeTab)
    }

    func syncSidebarAndLibrary(
        sidebar: WorkspaceSidebarSceneModel,
        library: LibraryManagementSceneModel,
        shell: WorkspaceShellSceneModel? = nil,
        activeTab: WorkspaceDetailTab? = nil
    ) {
        updateGraph(
            sidebar: sidebar,
            shell: shell,
            library: library,
            activeTab: activeTab
        )
    }

    func syncSettings(_ settings: SettingsPaneSceneModel) {
        updateGraph(settings: settings)
    }
}
