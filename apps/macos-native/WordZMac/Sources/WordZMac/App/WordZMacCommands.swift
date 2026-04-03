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
                openWindow(id: NativeWindowRoute.settings.id)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }

        CommandGroup(replacing: .newItem) {
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
        }

        CommandGroup(after: .newItem) {
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

            Button(t("快速预览当前内容", "Quick Look Current Content")) {
                NativeAppCommandCenter.post(.quickLookCurrentCorpus)
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])
            .disabled(!isEnabled(.previewCurrentCorpus))

            Button(t("分享当前内容", "Share Current Content")) {
                NativeAppCommandCenter.post(.shareCurrentContent)
            }
            .disabled(!isEnabled(.shareCurrentContent))

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
        }

        CommandMenu(t("工作区", "Workspace")) {
            Button(t("刷新工作区", "Refresh Workspace")) {
                NativeAppCommandCenter.post(.refreshWorkspace)
            }
            .keyboardShortcut("r", modifiers: [.command])

            Divider()

            Button(t("快速预览当前内容", "Quick Look Current Content")) {
                NativeAppCommandCenter.post(.quickLookCurrentCorpus)
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])
            .disabled(!isEnabled(.previewCurrentCorpus))

            Button(t("分享当前内容", "Share Current Content")) {
                NativeAppCommandCenter.post(.shareCurrentContent)
            }
            .disabled(!isEnabled(.shareCurrentContent))

            Button(t("导出当前结果…", "Export Current Result…")) {
                NativeAppCommandCenter.post(.exportCurrent)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!isEnabled(.exportCurrent))
        }

        CommandGroup(after: .windowArrangement) {
            Divider()

            windowButton(.library)
                .keyboardShortcut("1", modifiers: [.command])

            windowButton(.taskCenter)
                .keyboardShortcut("2", modifiers: [.command])

            windowButton(.settings)

            Divider()

            windowButton(.help)
            windowButton(.releaseNotes)
            windowButton(.about)
        }

        CommandMenu(t("分析", "Analysis")) {
            analysisCommand(t("统计", "Stats"), action: .runStats)
            analysisCommand(t("词表", "Word"), action: .runWord)
            analysisCommand(t("分词", "Tokenize"), action: .runTokenize)
            analysisCommand(t("主题", "Topics"), action: .runTopics)
            analysisCommand(t("对比", "Compare"), action: .runCompare)
            analysisCommand(t("卡方", "Chi-Square"), action: .runChiSquare)
            analysisCommand("N-Gram", action: .runNgram)
            analysisCommand(t("词云", "Word Cloud"), action: .runWordCloud)
            analysisCommand("KWIC", action: .runKWIC)
            analysisCommand(t("搭配词", "Collocate"), action: .runCollocate)
            analysisCommand(t("定位", "Locator"), action: .runLocator)
        }

        CommandGroup(replacing: .help) {
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
                Button(t("在 Finder 中显示已下载更新", "Reveal Downloaded Update in Finder")) {
                    Task { await workspace.revealDownloadedUpdate() }
                }
            }
            Button(t("导出诊断包…", "Export Diagnostics Bundle…")) {
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

    private func analysisCommand(_ title: String, action: WorkspaceToolbarAction) -> some View {
        Button(title) {
            NativeAppCommandCenter.post(nativeCommand(for: action))
        }
        .disabled(!isEnabled(action))
    }

    private func windowButton(_ route: NativeWindowRoute) -> some View {
        Button(route.title(in: localization.effectiveMode)) {
            openWindow(id: route.id)
        }
    }

    private func nativeCommand(for action: WorkspaceToolbarAction) -> NativeAppCommand {
        switch action {
        case .refresh:
            return .refreshWorkspace
        case .showLibrary:
            return .showLibrary
        case .openSelected:
            return .openSelectedCorpus
        case .previewCurrentCorpus:
            return .quickLookCurrentCorpus
        case .shareCurrentContent:
            return .shareCurrentContent
        case .runStats:
            return .runStats
        case .runWord:
            return .runWord
        case .runTokenize:
            return .runTokenize
        case .runTopics:
            return .runTopics
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
