import Foundation

@MainActor
final class WorkspaceSceneStore: ObservableObject {
    @Published private(set) var context = WorkspaceSceneContext.empty

    private var appInfo: AppInfoSummary?
    private var presentation: WorkspacePresentationSnapshot?
    private var buildSummary = WorkspaceSceneContext.empty.buildSummary

    func storeAppInfo(_ appInfo: AppInfoSummary?) {
        self.appInfo = appInfo
        syncContext()
    }

    func storePresentation(_ presentation: WorkspacePresentationSnapshot) {
        self.presentation = presentation
        syncContext()
    }

    func storeBuildSummary(_ buildSummary: String) {
        self.buildSummary = buildSummary
        syncContext()
    }

    func currentAppInfoSnapshot() -> AppInfoSummary? {
        appInfo
    }

    private func syncContext() {
        let versionLabel: String
        if let version = appInfo?.version, !version.isEmpty {
            versionLabel = "v\(version)"
        } else {
            versionLabel = "mac native preview"
        }

        context = WorkspaceSceneContext(
            appName: appInfo?.name ?? "WordZ",
            versionLabel: versionLabel,
            workspaceSummary: presentation?.workspaceSummary ?? WorkspaceSceneContext.empty.workspaceSummary,
            buildSummary: buildSummary,
            help: appInfo?.help ?? []
        )
    }
}
