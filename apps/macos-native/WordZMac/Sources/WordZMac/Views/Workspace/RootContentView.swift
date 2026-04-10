import SwiftUI

struct RootContentView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @Environment(\.openWindow) var openWindow
    @ObservedObject var viewModel: MainWorkspaceViewModel
    @StateObject var dispatcher: WorkspaceActionDispatcher
    @StateObject var windowToolbarController = MainWorkspaceWindowToolbarController()
    @ObservedObject var applicationDelegate: NativeApplicationDelegate
    @State var hasPresentedDefaultLaunchWindow = false
    var layoutState = WorkspaceWindowLayoutState()

    init(
        viewModel: MainWorkspaceViewModel,
        applicationDelegate: NativeApplicationDelegate = NativeApplicationDelegate()
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _dispatcher = StateObject(
            wrappedValue: WorkspaceActionDispatcher(
                workspace: viewModel,
                preferredWindowRoute: .mainWorkspace
            )
        )
        _applicationDelegate = ObservedObject(wrappedValue: applicationDelegate)
    }

    var body: some View {
        workspaceContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(shellLifecycleModifier)
    }
}
