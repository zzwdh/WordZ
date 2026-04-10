import Foundation

enum NativeUpdateCheckTrigger {
    case manual
    case launch
}

@MainActor
extension MainWorkspaceViewModel {
    func scheduleLaunchUpdateCheckIfNeeded() {
        guard !hasScheduledLaunchUpdateWorkflow else { return }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        hasScheduledLaunchUpdateWorkflow = true

        let shouldPresentDownloadedUpdate = settings.scene.canInstallDownloadedUpdate
        let shouldCheckOnLaunch = settings.autoUpdateEnabled && settings.checkForUpdatesOnLaunch
        guard shouldPresentDownloadedUpdate || shouldCheckOnLaunch else { return }

        launchUpdateCheckTask?.cancel()
        launchUpdateCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled, let self else { return }
            if shouldPresentDownloadedUpdate {
                NativeAppCommandCenter.post(.showUpdateWindow)
            }
            guard shouldCheckOnLaunch else { return }
            await self.checkForUpdatesNow(cancelPendingLaunchTask: false, trigger: .launch)
        }
    }

    func checkForUpdatesNow(
        cancelPendingLaunchTask: Bool = true,
        trigger: NativeUpdateCheckTrigger = .manual
    ) async {
        guard !isRunningUpdateCheck else { return }
        if cancelPendingLaunchTask {
            launchUpdateCheckTask?.cancel()
        }
        launchUpdateCheckTask = nil
        isRunningUpdateCheck = true

        let taskID = taskCenter.beginTask(
            title: t("检查更新", "Check for Updates"),
            detail: t("正在检查最新版本…", "Checking for the latest release…"),
            progress: 0
        )
        applyUpdateStateSnapshot(makeUpdateStateSnapshot(isChecking: true))

        defer {
            isRunningUpdateCheck = false
        }

        do {
            let result = try await updateService.checkForUpdates(currentVersion: currentVersionForUpdateChecks)
            latestCheckedUpdate = result
            let preferences = try hostPreferencesStore.recordUpdateCheck(status: result.statusMessage)
            settings.applyHostPreferences(preferences, preservingRuntimeUpdatePolicy: true)
            let snapshot = makeUpdateStateSnapshot(from: result, preferences: preferences)
            applyUpdateStateSnapshot(snapshot)
            settings.setSupportStatus(result.statusMessage)
            clearActiveIssue()

            let completedAction: NativeBackgroundTaskAction? = result.updateAvailable ? .openURL(result.releaseURL) : nil
            taskCenter.completeTask(id: taskID, detail: result.statusMessage, action: completedAction)

            if result.updateAvailable && trigger == .launch {
                NativeAppCommandCenter.post(.showUpdateWindow)
            }

            if settings.autoDownloadUpdates && snapshot.canDownloadUpdate && trigger != .launch {
                await downloadLatestUpdate(
                    using: result,
                    installAfterDownload: settings.autoInstallDownloadedUpdates
                )
            }
        } catch is CancellationError {
            let cancelledMessage = t("已取消检查更新。", "Update check was cancelled.")
            applyUpdateStateSnapshot(makeUpdateStateSnapshot(statusMessage: cancelledMessage))
            settings.setSupportStatus(cancelledMessage)
            clearActiveIssue()
            taskCenter.failTask(id: taskID, detail: cancelledMessage)
        } catch {
            let message = error.localizedDescription
            applyUpdateStateSnapshot(makeUpdateStateSnapshot(statusMessage: message))
            settings.setSupportStatus(message)
            if trigger == .launch {
                clearActiveIssue()
            } else {
                presentIssue(
                    error,
                    titleZh: "更新检查失败",
                    titleEn: "Update Check Failed",
                    recoveryAction: .checkForUpdates
                )
            }
            taskCenter.failTask(id: taskID, detail: message)
        }
    }

    func downloadLatestUpdate() async {
        if let latestCheckedUpdate {
            await downloadLatestUpdate(using: latestCheckedUpdate)
            return
        }

        let result: NativeUpdateCheckResult
        do {
            result = try await updateService.checkForUpdates(currentVersion: currentVersionForUpdateChecks)
            latestCheckedUpdate = result
            let preferences = try hostPreferencesStore.recordUpdateCheck(status: result.statusMessage)
            settings.applyHostPreferences(preferences, preservingRuntimeUpdatePolicy: true)
            applyUpdateStateSnapshot(makeUpdateStateSnapshot(from: result, preferences: preferences))
        } catch {
            presentIssue(
                error,
                titleZh: "下载更新失败",
                titleEn: "Update Download Failed",
                recoveryAction: .checkForUpdates
            )
            return
        }

        await downloadLatestUpdate(using: result)
    }
}
