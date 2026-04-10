import Foundation

@MainActor
extension WorkspaceSceneStore {
    func applyAppInfo(_ appInfo: AppInfoSummary?) {
        storeAppInfo(appInfo)
    }

    func applyPresentation(_ presentation: WorkspacePresentationSnapshot) {
        storePresentation(presentation)
    }

    func setBuildSummary(_ buildSummary: String) {
        storeBuildSummary(buildSummary)
    }
}
