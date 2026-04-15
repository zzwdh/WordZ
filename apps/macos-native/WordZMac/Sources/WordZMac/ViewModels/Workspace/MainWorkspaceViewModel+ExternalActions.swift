import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func presentWelcome() {
        isWelcomePresented = true
    }

    func dismissWelcome() {
        isWelcomePresented = false
    }

    func openUserDataDirectory() async {
        guard !settings.scene.userDataDirectory.isEmpty else {
            settings.setSupportStatus(t("当前没有可用的用户数据目录。", "No user data directory is available right now."))
            return
        }
        do {
            try await hostActionService.openUserDataDirectory(path: settings.scene.userDataDirectory)
            settings.setSupportStatus(t("已在 Finder 中打开用户数据目录。", "Opened the user data directory in Finder."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开用户数据目录", titleEn: "Unable to Open User Data Directory")
        }
    }

    func openFeedback() async {
        do {
            try await hostActionService.openFeedback()
            settings.setSupportStatus(t("已打开反馈页。", "Opened the feedback page."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开反馈入口", titleEn: "Unable to Open Feedback")
        }
    }

    func openProjectHome() async {
        do {
            try await hostActionService.openProjectHome()
            settings.setSupportStatus(t("已打开项目主页。", "Opened the project home page."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开项目主页", titleEn: "Unable to Open Project Home")
        }
    }

    func quickLookCurrentCorpus() async {
        guard let target = currentContentTarget else {
            presentQuickLookUnavailableIssue()
            return
        }
        do {
            try await hostActionService.quickLook(path: try preparedPath(for: target))
            settings.setSupportStatus(t("已打开当前内容的 Quick Look 预览。", "Opened Quick Look for the current content."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开 Quick Look 预览", titleEn: "Unable to Open Quick Look")
        }
    }

    func quickLookSelectedCorpus() async {
        guard let path = selectedCorpusPreviewablePath else {
            presentQuickLookUnavailableIssue()
            return
        }
        do {
            try await hostActionService.quickLook(path: path)
            settings.setSupportStatus(t("已打开所选语料的 Quick Look 预览。", "Opened Quick Look for the selected corpus."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开 Quick Look 预览", titleEn: "Unable to Open Quick Look")
        }
    }

    func shareCurrentContent() async {
        guard let target = currentContentTarget else {
            presentShareUnavailableIssue()
            return
        }
        do {
            try await hostActionService.share(paths: [try preparedPath(for: target)])
            settings.setSupportStatus(t("已打开当前内容的系统分享菜单。", "Opened the system share menu for the current content."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开系统分享菜单", titleEn: "Unable to Open Share Menu")
        }
    }

    func shareSelectedCorpus() async {
        guard let path = selectedCorpusPreviewablePath else {
            presentShareUnavailableIssue()
            return
        }
        do {
            try await hostActionService.share(paths: [path])
            settings.setSupportStatus(t("已打开所选语料的系统分享菜单。", "Opened the system share menu for the selected corpus."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开系统分享菜单", titleEn: "Unable to Open Share Menu")
        }
    }

    func openReleaseNotes() async {
        do {
            try await hostActionService.openReleaseNotes()
            settings.setSupportStatus(t("已打开版本说明页。", "Opened the release notes page."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开版本说明", titleEn: "Unable to Open Release Notes")
        }
    }
}
