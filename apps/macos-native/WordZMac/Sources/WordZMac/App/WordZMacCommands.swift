import SwiftUI

struct WordZMacCommands: Commands {
    @ObservedObject var workspace: MainWorkspaceViewModel
    @ObservedObject private var localization = WordZLocalization.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        SidebarCommands()
        TextEditingCommands()

        CommandGroup(replacing: .appInfo) {
            Button(t("关于 WordZ", "About WordZ")) {
                openWindow(id: NativeWindowRoute.about.id)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(t("设置…", "Settings…")) {
                NativeAppCommandCenter.post(.showSettings)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }

        CommandMenu(t("文件", "File")) {
            Button(t("新建工作区", "New Workspace")) {
                NativeAppCommandCenter.post(.newWorkspace)
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button(t("恢复已保存工作区", "Restore Saved Workspace")) {
                NativeAppCommandCenter.post(.restoreWorkspace)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!workspace.canRestoreWorkspace)

            Button(t("显示欢迎页", "Show Welcome")) {
                NativeAppCommandCenter.post(.showWelcome)
            }
            .keyboardShortcut("/", modifiers: [.command, .shift])

            Divider()

            Button(t("导入语料…", "Import Corpora…")) {
                NativeAppCommandCenter.post(.importCorpora)
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button(t("打开已选语料", "Open Selected Corpus")) {
                NativeAppCommandCenter.post(.openSelectedCorpus)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
            .disabled(!isEnabled(.openSelected))

            Menu(t("最近打开", "Recent Documents")) {
                if recentDocuments.isEmpty {
                    Button(t("没有最近打开记录", "No recent documents")) { }
                        .disabled(true)
                } else {
                    ForEach(recentDocuments) { item in
                        Button(item.title) {
                            Task { await workspace.openRecentDocument(item.corpusID) }
                        }
                    }
                    Divider()
                    Button(t("清空最近打开", "Clear Recent Documents")) {
                        Task { await workspace.clearRecentDocuments() }
                    }
                }
            }
            .disabled(recentDocuments.isEmpty)

            Divider()

            Button(t("导出当前结果…", "Export Current Result…")) {
                NativeAppCommandCenter.post(.exportCurrent)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!isEnabled(.exportCurrent))

            if workspace.settings.scene.canInstallDownloadedUpdate {
                Divider()
                Button(t("安装已下载更新", "Install Downloaded Update")) {
                    NativeAppCommandCenter.post(.installDownloadedUpdate)
                }
                Button(t("在 Finder 中显示已下载更新", "Reveal Downloaded Update in Finder")) {
                    Task { await workspace.revealDownloadedUpdate() }
                }
            }
        }

        CommandMenu(t("视图", "View")) {
            viewCommand(t("语料库", "Library"), shortcut: "1", action: .showLibrary)
            viewCommand(t("统计", "Stats"), shortcut: "2", action: .runStats)
            viewCommand(t("词表", "Word"), shortcut: "3", action: .runWord)
            viewCommand("KWIC", shortcut: "4", action: .runKWIC)
            viewCommand(t("搭配词", "Collocate"), shortcut: "5", action: .runCollocate)
            viewCommand(t("设置", "Settings"), shortcut: ",", modifiers: [.command], action: .showSettings)
            Divider()
            Button(t("刷新工作区", "Refresh Workspace")) {
                NativeAppCommandCenter.post(.refreshWorkspace)
            }
            .keyboardShortcut("r", modifiers: [.command])
        }

        CommandMenu(t("分析", "Analysis")) {
            analysisCommand(t("统计", "Stats"), action: .runStats)
            analysisCommand(t("词表", "Word"), action: .runWord)
            analysisCommand(t("对比", "Compare"), action: .runCompare)
            analysisCommand(t("卡方", "Chi-Square"), action: .runChiSquare)
            analysisCommand("N-Gram", action: .runNgram)
            analysisCommand(t("词云", "Word Cloud"), action: .runWordCloud)
            analysisCommand("KWIC", action: .runKWIC)
            analysisCommand(t("搭配词", "Collocate"), action: .runCollocate)
            analysisCommand(t("定位", "Locator"), action: .runLocator)
        }

        CommandMenu(t("窗口", "Window")) {
            Button(t("任务中心", "Task Center")) {
                openWindow(id: NativeWindowRoute.taskCenter.id)
            }
            .keyboardShortcut("0", modifiers: [.command, .option])

            Button(t("帮助中心", "Help Center")) {
                openWindow(id: NativeWindowRoute.help.id)
            }

            Button(t("版本说明", "Release Notes")) {
                openWindow(id: NativeWindowRoute.releaseNotes.id)
            }

            Button(t("关于 WordZ", "About WordZ")) {
                openWindow(id: NativeWindowRoute.about.id)
            }
        }

        CommandGroup(after: .windowArrangement) {
            Button(t("任务中心", "Task Center")) {
                openWindow(id: NativeWindowRoute.taskCenter.id)
            }
        }

        CommandMenu(t("帮助", "Help")) {
            Button(t("检查更新…", "Check for Updates…")) {
                NativeAppCommandCenter.post(.checkForUpdates)
            }

            if workspace.settings.scene.canDownloadUpdate {
                Button(t("下载更新", "Download Update")) {
                    NativeAppCommandCenter.post(.downloadUpdate)
                }
            }

            if workspace.settings.scene.canInstallDownloadedUpdate {
                Button(t("安装已下载更新", "Install Downloaded Update")) {
                    NativeAppCommandCenter.post(.installDownloadedUpdate)
                }
            }

            Divider()

            Button(t("帮助中心", "Help Center")) {
                openWindow(id: NativeWindowRoute.help.id)
            }
            Button(t("版本说明", "Release Notes")) {
                openWindow(id: NativeWindowRoute.releaseNotes.id)
            }
            Button(t("导出诊断…", "Export Diagnostics…")) {
                NativeAppCommandCenter.post(.exportDiagnostics)
            }

            Divider()

            Button(t("项目主页", "Project Home")) {
                NativeAppCommandCenter.post(.openProjectHome)
            }
            Button(t("GitHub 反馈", "GitHub Feedback")) {
                NativeAppCommandCenter.post(.openFeedback)
            }
        }
    }

    private var recentDocuments: [RecentDocumentItem] {
        workspace.settings.scene.recentDocuments
    }

    private func isEnabled(_ action: WorkspaceToolbarAction) -> Bool {
        workspace.rootScene.toolbar.items.first(where: { $0.action == action })?.isEnabled ?? true
    }

    private func viewCommand(
        _ title: String,
        shortcut: KeyEquivalent,
        modifiers: EventModifiers = [.command],
        action: NativeAppCommand
    ) -> some View {
        Button(title) {
            NativeAppCommandCenter.post(action)
        }
        .keyboardShortcut(shortcut, modifiers: modifiers)
    }

    private func analysisCommand(_ title: String, action: WorkspaceToolbarAction) -> some View {
        Button(title) {
            NativeAppCommandCenter.post(nativeCommand(for: action))
        }
        .disabled(!isEnabled(action))
    }

    private func nativeCommand(for action: WorkspaceToolbarAction) -> NativeAppCommand {
        switch action {
        case .refresh:
            return .refreshWorkspace
        case .showLibrary:
            return .showLibrary
        case .openSelected:
            return .openSelectedCorpus
        case .runStats:
            return .runStats
        case .runWord:
            return .runWord
        case .runCompare:
            return .runCompare
        case .runChiSquare:
            return .runChiSquare
        case .runNgram:
            return .runNgram
        case .runWordCloud:
            return .runWordCloud
        case .runKWIC:
            return .runKWIC
        case .runCollocate:
            return .runCollocate
        case .runLocator:
            return .runLocator
        case .exportCurrent:
            return .exportCurrent
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        localization.text(zh, en)
    }
}
