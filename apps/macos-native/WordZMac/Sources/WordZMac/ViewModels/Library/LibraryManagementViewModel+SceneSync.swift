import Foundation

@MainActor
extension LibraryManagementViewModel {
    func requestSceneSync() {
        if deferredSceneSyncDepth > 0 {
            needsDeferredSceneSync = true
            return
        }
        syncScene()
    }

    func deferSceneSync(_ updates: () -> Void) {
        deferredSceneSyncDepth += 1
        defer {
            deferredSceneSyncDepth -= 1
            if deferredSceneSyncDepth == 0, needsDeferredSceneSync {
                needsDeferredSceneSync = false
                syncScene()
            }
        }
        updates()
    }
}
