import SwiftUI

extension RootContentView {
    @ViewBuilder
    var currentDetailView: some View {
        WorkspaceFeatureFactory.makeDetailView(
            for: viewModel.selectedRoute,
            workspace: viewModel,
            dispatcher: dispatcher
        )
    }
}
