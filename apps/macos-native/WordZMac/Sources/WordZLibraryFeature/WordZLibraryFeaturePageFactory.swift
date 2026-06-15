import WordZWorkspaceCore

@MainActor
package enum WordZLibraryFeaturePageFactory {
    package static func makePageBundle() -> WorkspaceLibraryPageBundle {
        WorkspaceLibraryPageBundle(
            sidebar: LibrarySidebarViewModel(),
            library: LibraryManagementViewModel()
        )
    }
}
