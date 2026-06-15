import Foundation

@MainActor
package struct WorkspaceLibraryPageBundle {
    package let sidebar: LibrarySidebarViewModel
    package let library: LibraryManagementViewModel

    package init(
        sidebar: LibrarySidebarViewModel,
        library: LibraryManagementViewModel
    ) {
        self.sidebar = sidebar
        self.library = library
    }

    package static func makeDefault() -> WorkspaceLibraryPageBundle {
        WorkspaceLibraryPageBundle(
            sidebar: LibrarySidebarViewModel(),
            library: LibraryManagementViewModel()
        )
    }
}
