import SwiftUI

extension RootContentView {
    var workspaceContent: some View {
        MainWorkspaceSplitContainer(
            isSidebarVisible: layoutState.sidebarVisibilityBinding,
            isInspectorVisible: layoutState.inspectorVisibilityBinding,
            contentRevision: workspaceSplitContentRevision,
            topAccessory: usesWorkspaceTopAccessory ? workspaceTopAccessoryContent : nil
        ) {
            workspaceSidebarPane
        } detail: {
            workspaceMainPane
        } inspector: {
            workspaceInspectorPane
        }
    }

    var workspaceSidebarPane: some View {
        SidebarView(
            viewModel: viewModel.sidebar,
            selectedRoute: selectedRouteBinding,
            openAnalysis: commandHandler.selectTab
        )
    }

    var workspaceMainPane: some View {
        VStack(spacing: 0) {
            if !usesWorkspaceTopAccessory {
                workspaceIssueBanner
            }

            currentDetailView
                .environmentObject(viewModel.lexicalAutocomplete)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .safeAreaInset(edge: .bottom) {
                    workspaceResultActionAccessory
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WordZTheme.workspaceBackground(for: WordZVisualStyle.resolve(for: .mainWorkspace)))
    }

    var workspaceInspectorPane: some View {
        workspaceInspector
    }

    var selectedRouteBinding: Binding<WorkspaceMainRoute?> {
        Binding(
            get: { viewModel.selectedRoute },
            set: { nextValue in
                guard let nextValue else { return }
                guard viewModel.selectedRoute != nextValue else { return }
                shellActionHandler.handle(.selectRoute(nextValue))
            }
        )
    }

    var usesWorkspaceTopAccessory: Bool {
        NativeWindowPresentationProfile.profile(for: .mainWorkspace)
            .resolvedSplitAccessoryMode(capabilities: .current) == .mainWorkspaceTopAccessory
    }

    var workspaceTopAccessoryContent: AnyView? {
        guard viewModel.issueBanner != nil else { return nil }
        return AnyView(
            workspaceIssueBanner
                .wordZVisualStyle(WordZVisualStyle.resolveAccessory(for: .mainWorkspace))
        )
    }

    var workspaceSplitContentRevision: WorkspaceSplitContentRevision {
        let sceneRevisions = viewModel.lastAppliedSceneGraphContentRevisions
        let selectedRoute = viewModel.selectedRoute
        let activeResultRevision = sceneRevisions.resultRevision(for: viewModel.selectedTab)
        let issueBannerID = viewModel.issueBanner?.id
        let activeRunningTaskKeys: Set<WorkspaceRuntimeTaskKey>
        if let activeTaskKey = selectedRoute.tab.runtimeTaskKey,
           viewModel.runningTaskKeys.contains(activeTaskKey) {
            activeRunningTaskKeys = [activeTaskKey]
        } else {
            activeRunningTaskKeys = []
        }

        return WorkspaceSplitContentRevision(
            sidebar: WorkspaceSplitPaneContentRevision(
                components: [
                    sceneRevisions.sidebar,
                    sceneRevisions.activeTab
                ],
                selectedRoute: selectedRoute,
                languageMode: languageMode
            ),
            detail: WorkspaceSplitPaneContentRevision(
                components: [
                    sceneRevisions.activeTab,
                    sceneRevisions.shell
                ],
                selectedRoute: selectedRoute,
                runningTaskKeys: activeRunningTaskKeys,
                languageMode: languageMode,
                annotationState: viewModel.annotationState
            ),
            inspector: WorkspaceSplitPaneContentRevision(
                components: [
                    sceneRevisions.sidebar,
                    sceneRevisions.shell,
                    sceneRevisions.activeTab,
                    activeResultRevision
                ],
                selectedRoute: selectedRoute,
                issueBannerID: usesWorkspaceTopAccessory ? nil : issueBannerID,
                languageMode: languageMode
            ),
            accessoryRevisionID: usesWorkspaceTopAccessory ? issueBannerID : nil
        )
    }
}
