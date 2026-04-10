import Foundation

@MainActor
protocol WorkspaceBootstrapApplying {
    func apply(_ bootstrapState: WorkspaceBootstrapState, to features: WorkspaceFeatureSet)
    func finalizeRefresh(features: WorkspaceFeatureSet) async
}
