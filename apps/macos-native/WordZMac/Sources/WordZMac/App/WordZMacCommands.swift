import AppKit
import SwiftUI

struct WordZMacCommands: Commands {
    @ObservedObject var workspace: MainWorkspaceViewModel
    @ObservedObject private var shell: WorkspaceShellViewModel
    @ObservedObject private var localization = WordZLocalization.shared
    @Environment(\.openWindow) private var openWindow

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
        _shell = ObservedObject(wrappedValue: workspace.shell)
    }

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
                NativeSettingsSupport.openSettingsWindow()
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

            Divider()

            Button(t("保存当前分析预设…", "Save Current Analysis Preset…")) {
                Task { await workspace.saveCurrentAnalysisPreset() }
            }
            .disabled(!workspace.canManageAnalysisPresets)

            Menu(t("应用分析预设", "Apply Analysis Preset")) {
                if workspace.analysisPresets.isEmpty {
                    Button(t("还没有已保存预设", "No saved presets yet")) { }
                        .disabled(true)
                } else {
                    ForEach(workspace.analysisPresets) { preset in
                        Button("\(preset.name) · \(preset.summary(in: localization.effectiveMode))") {
                            Task { await workspace.applyAnalysisPreset(preset.id) }
                        }
                    }
                }
            }
            .disabled(!workspace.canManageAnalysisPresets || workspace.analysisPresets.isEmpty)

            Menu(t("删除分析预设", "Delete Analysis Preset")) {
                if workspace.analysisPresets.isEmpty {
                    Button(t("还没有已保存预设", "No saved presets yet")) { }
                        .disabled(true)
                } else {
                    ForEach(workspace.analysisPresets) { preset in
                        Button(preset.name, role: .destructive) {
                            Task { await workspace.deleteAnalysisPreset(preset.id) }
                        }
                    }
                }
            }
            .disabled(!workspace.canManageAnalysisPresets || workspace.analysisPresets.isEmpty)

            Button(t("导出研究报告包…", "Export Research Report Bundle…")) {
                Task { await workspace.exportCurrentReportBundle() }
            }
            .disabled(!workspace.canExportCurrentReportBundle)
        }

        CommandGroup(after: .windowArrangement) {
            Divider()

            windowButton(.library)
                .keyboardShortcut("1", modifiers: [.command])

            windowButton(.taskCenter)
                .keyboardShortcut("2", modifiers: [.command])

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
            analysisCommand(t("关键词", "Keyword"), action: .runKeyword)
            analysisCommand(t("卡方", "Chi-Square"), action: .runChiSquare)
            analysisCommand("N-Gram", action: .runNgram)
            analysisCommand("KWIC", action: .runKWIC)
            analysisCommand(t("搭配词", "Collocate"), action: .runCollocate)
            analysisCommand(t("定位", "Locator"), action: .runLocator)
        }

        CommandGroup(replacing: .help) {
            Button(t("检查更新…", "Check for Updates…")) {
                NativeAppCommandCenter.post(.checkForUpdates)
            }

            if workspace.settings.scene.canDownloadUpdate || workspace.settings.scene.canInstallDownloadedUpdate || workspace.settings.scene.isDownloadingUpdate {
                Button(t("打开更新窗口", "Open Update Window")) {
                    NativeAppCommandCenter.post(.showUpdateWindow)
                }
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
        shell.scene.toolbar.items.first(where: { $0.action == action })?.isEnabled ?? true
    }

    private func analysisCommand(_ title: String, action: WorkspaceToolbarAction) -> some View {
        Button(title) {
            NativeAppCommandCenter.post(action.nativeCommand)
        }
        .disabled(!isEnabled(action))
    }

    private func windowButton(_ route: NativeWindowRoute) -> some View {
        Button(route.title(in: localization.effectiveMode)) {
            openWindow(id: route.id)
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        localization.text(zh, en)
    }
}
