import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func clearFinishedTasks() {
        taskCenter.clearFinished()
        syncSceneGraph(source: .settings)
    }

    func persistTaskHistory(_ history: [PersistedNativeBackgroundTaskItem]) {
        guard history != lastPersistedTaskHistory else { return }
        lastPersistedTaskHistory = history

        do {
            var snapshot = hostPreferencesStore.load()
            snapshot.taskHistory = history
            try hostPreferencesStore.save(snapshot)
        } catch {
            settings.setSupportStatus(error.localizedDescription)
        }
    }

    func performTaskAction(_ action: NativeBackgroundTaskAction) async {
        switch action {
        case .cancelTask(let id):
            taskCenter.cancelTask(id: id)
        case .openFile(let path):
            do {
                try await hostActionService.openFile(path: path)
            } catch {
                presentIssue(error, titleZh: "无法打开文件", titleEn: "Unable to Open File")
            }
        case .openURL(let value):
            do {
                try await hostActionService.openURL(value)
            } catch {
                presentIssue(error, titleZh: "无法打开链接", titleEn: "Unable to Open URL")
            }
        case .installDownloadedUpdate(let path):
            do {
                try await hostActionService.openDownloadedUpdate(path: path)
                settings.setSupportStatus(t("已打开下载的更新包。", "Opened the downloaded update package."))
                clearActiveIssue()
            } catch {
                presentIssue(error, titleZh: "无法打开更新包", titleEn: "Unable to Open Update Package")
            }
        }
    }
}
