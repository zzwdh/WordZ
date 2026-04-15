import SwiftUI

enum WorkspaceFeatureFactory {
    @MainActor
    static func makeDetailView(
        for route: WorkspaceMainRoute,
        workspace: MainWorkspaceViewModel,
        dispatcher: WorkspaceActionDispatcher
    ) -> AnyView {
        WorkspaceFeatureRegistry.descriptor(for: route).makeDetailView(
            workspace: workspace,
            dispatcher: dispatcher
        )
    }
}
