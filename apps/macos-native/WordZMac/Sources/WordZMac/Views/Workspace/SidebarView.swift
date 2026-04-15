import SwiftUI

struct SidebarView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: LibrarySidebarViewModel
    @Binding var selectedRoute: WorkspaceMainRoute?
    let openAnalysis: (WorkspaceDetailTab) -> Void

    var body: some View {
        List {
            sidebarSections
        }
        .listStyle(.sidebar)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
