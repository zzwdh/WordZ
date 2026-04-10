import SwiftUI

struct SidebarView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: LibrarySidebarViewModel
    @Binding var selectedRoute: WorkspaceMainRoute?

    var body: some View {
        List(selection: $selectedRoute) {
            sidebarSections
        }
        .listStyle(.sidebar)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
