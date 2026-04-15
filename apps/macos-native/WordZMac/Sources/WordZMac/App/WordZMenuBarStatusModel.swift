import Foundation

@MainActor
final class WordZMenuBarStatusModel: ObservableObject {
    @Published private(set) var iconState: WordZMenuBarIconState = .idle

    private var hasRunningTasks = false
    private var canInstallDownloadedUpdate = false
    private var isDownloadingUpdate = false

    func applyTaskCenterScene(_ scene: NativeTaskCenterSceneModel) {
        hasRunningTasks = scene.runningCount > 0
        syncIconState()
    }

    func applyUpdateState(_ snapshot: NativeUpdateStateSnapshot) {
        canInstallDownloadedUpdate = snapshot.canInstallDownloadedUpdate
        isDownloadingUpdate = snapshot.isDownloading
        syncIconState()
    }

    private func syncIconState() {
        let nextState: WordZMenuBarIconState
        if canInstallDownloadedUpdate {
            nextState = .updateReady
        } else if hasRunningTasks || isDownloadingUpdate {
            nextState = .tasksRunning
        } else {
            nextState = .idle
        }

        guard nextState != iconState else { return }
        iconState = nextState
    }
}
