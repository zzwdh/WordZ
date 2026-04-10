import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func installLatestUpdateAndRestart() async {
        let existingPath = settings.scene.downloadedUpdatePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existingPath.isEmpty {
            await openDownloadedUpdateAndTerminate(path: existingPath)
            return
        }

        if let latestCheckedUpdate {
            await downloadLatestUpdate(using: latestCheckedUpdate, installAfterDownload: true)
            return
        }

        let result: NativeUpdateCheckResult
        do {
            result = try await updateService.checkForUpdates(currentVersion: currentVersionForUpdateChecks)
            latestCheckedUpdate = result
            let preferences = try hostPreferencesStore.recordUpdateCheck(status: result.statusMessage)
            settings.applyHostPreferences(preferences, preservingRuntimeUpdatePolicy: true)
            applyUpdateStateSnapshot(makeUpdateStateSnapshot(from: result, preferences: preferences))
            if result.updateAvailable {
                NativeAppCommandCenter.post(.showUpdateWindow)
            }
        } catch {
            presentIssue(
                error,
                titleZh: "无法启动更新安装",
                titleEn: "Unable to Start Update Installation",
                recoveryAction: .checkForUpdates
            )
            return
        }

        guard result.updateAvailable else {
            settings.setSupportStatus(result.statusMessage)
            clearActiveIssue()
            return
        }

        await downloadLatestUpdate(using: result, installAfterDownload: true)
    }

    func installDownloadedUpdate() async {
        let path = settings.scene.downloadedUpdatePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            presentMissingDownloadedUpdateIssue(
                titleZh: "无法安装更新",
                titleEn: "Unable to Install Update"
            )
            return
        }

        do {
            try await hostActionService.openDownloadedUpdate(path: path)
            settings.setSupportStatus(t("已打开下载的更新包。", "Opened the downloaded update package."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开更新包", titleEn: "Unable to Open Update Package")
        }
    }

    func revealDownloadedUpdate() async {
        let path = settings.scene.downloadedUpdatePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            presentMissingDownloadedUpdateIssue(
                titleZh: "无法显示更新包",
                titleEn: "Unable to Reveal Update Package"
            )
            return
        }

        do {
            try await hostActionService.revealDownloadedUpdate(path: path)
            settings.setSupportStatus(t("已在 Finder 中显示下载的更新包。", "Revealed the downloaded update package in Finder."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法显示更新包", titleEn: "Unable to Reveal Update Package")
        }
    }

    func disableAutomaticUpdateDownloadsAndInstall() async {
        settings.autoInstallDownloadedUpdates = false
        settings.autoDownloadUpdates = false
        settings.setSupportStatus(t("已关闭自动下载安装。", "Automatic download and install has been turned off."))
        await saveSettings()
        clearActiveIssue()
    }

    func downloadLatestUpdate(
        using checkedResult: NativeUpdateCheckResult,
        installAfterDownload: Bool = false
    ) async {
        guard !isRunningUpdateDownload else { return }
        guard checkedResult.updateAvailable else {
            settings.setSupportStatus(checkedResult.statusMessage)
            return
        }
        guard checkedResult.asset != nil else {
            settings.setSupportStatus(checkedResult.statusMessage)
            return
        }

        isRunningUpdateDownload = true
        let taskID = taskCenter.beginTask(
            title: t("下载更新", "Download Update"),
            detail: t("正在下载更新安装包…", "Downloading the update package…"),
            progress: 0
        )
        applyUpdateStateSnapshot(makeUpdateStateSnapshot(from: checkedResult, isDownloading: true, downloadProgress: 0))

        defer {
            isRunningUpdateDownload = false
        }

        do {
            let downloaded = try await updateService.downloadUpdate(checkedResult) { progress in
                self.taskCenter.updateTask(
                    id: taskID,
                    detail: self.t("正在下载更新安装包…", "Downloading the update package…"),
                    progress: progress
                )
                self.applyUpdateStateSnapshot(
                    self.makeUpdateStateSnapshot(
                        from: checkedResult,
                        isDownloading: true,
                        downloadProgress: progress
                    )
                )
            }
            let preferences = try hostPreferencesStore.recordDownloadedUpdate(
                version: downloaded.version,
                name: downloaded.assetName,
                path: downloaded.localPath
            )
            settings.applyHostPreferences(preferences, preservingRuntimeUpdatePolicy: true)
            let snapshot = makeUpdateStateSnapshot(from: checkedResult, preferences: preferences)
            applyUpdateStateSnapshot(snapshot)
            let detail = t("更新包已下载：", "Downloaded update: ") + downloaded.assetName
            settings.setSupportStatus(detail)
            clearActiveIssue()
            if installAfterDownload {
                taskCenter.completeTask(id: taskID, detail: detail)
                await openDownloadedUpdateAndTerminate(path: downloaded.localPath)
            } else {
                taskCenter.completeTask(
                    id: taskID,
                    detail: detail,
                    action: .installDownloadedUpdate(path: downloaded.localPath)
                )
            }
        } catch {
            applyUpdateStateSnapshot(makeUpdateStateSnapshot(from: checkedResult))
            presentIssue(error, titleZh: "下载更新失败", titleEn: "Update Download Failed")
            taskCenter.failTask(id: taskID, detail: error.localizedDescription)
        }
    }

    func presentMissingDownloadedUpdateIssue(titleZh: String, titleEn: String) {
        let message = t("当前没有已下载的更新包。", "There is no downloaded update available.")
        settings.setSupportStatus(message)
        activeIssue = WorkspaceIssueBanner(
            tone: .warning,
            title: t(titleZh, titleEn),
            message: message,
            recoveryAction: .checkForUpdates
        )
    }

    private func openDownloadedUpdateAndTerminate(path: String) async {
        do {
            try await hostActionService.openDownloadedUpdateAndTerminate(path: path)
            settings.setSupportStatus(
                t(
                    "已启动安装流程，当前版本会退出，安装完成后请重新打开应用。",
                    "The installer has been opened and the current app will quit. Reopen WordZ after installation finishes."
                )
            )
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法启动更新安装", titleEn: "Unable to Start Update Installation")
        }
    }
}
