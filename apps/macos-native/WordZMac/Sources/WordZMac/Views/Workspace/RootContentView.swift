import SwiftUI

struct RootContentView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @Environment(\.openWindow) var openWindow
    @ObservedObject var viewModel: MainWorkspaceViewModel
    @StateObject var dispatcher: WorkspaceActionDispatcher
    @ObservedObject var applicationDelegate: NativeApplicationDelegate
    @State var hasPresentedDefaultLaunchWindow = false
    @State var presentedIssueBanner: WorkspaceIssueBanner?
    @State var dismissedIssueBannerID: String?
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
            .adaptiveWindowScaffold(for: .mainWorkspace)
            .toolbar {
                if NativeWindowPresentationProfile.profile(for: .mainWorkspace)
                    .resolvedToolbarMode(capabilities: .current) == .swiftUIPrimary {
                    MainWorkspaceWindowToolbar(
                        toolbar: viewModel.shell.scene.toolbar,
                        selectedRoute: viewModel.selectedRoute,
                        languageMode: languageMode,
                        isSidebarVisible: isSidebarVisible,
                        isInspectorVisible: isInspectorVisible,
                        onToggleSidebar: { shellActionHandler.handle(.toggleSidebar) },
                        onToggleInspector: { shellActionHandler.handle(.toggleInspector) },
                        onPostCommand: { NativeAppCommandCenter.post($0) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusedValue(\.workspaceCommandContext, mainWorkspaceCommandContext)
            .importedPathDropDestination(route: .mainWorkspace) { paths in
                await viewModel.handleExternalPaths(paths)
            }
            .sheet(item: workspaceIssueSheetBinding) { banner in
                workspaceIssueSheet(banner)
            }
            .onAppear {
                syncWorkspaceIssuePresentation(with: viewModel.issueBanner)
            }
            .onChange(of: viewModel.issueBanner) { _, newValue in
                syncWorkspaceIssuePresentation(with: newValue)
            }
            .modifier(shellLifecycleModifier)
    }
}
