import AppKit
import OSLog
import SwiftUI

private let commandLogger = WordZTelemetry.logger(category: "Commands")

struct WordZMacCommands: Commands {
    @ObservedObject var workspace: MainWorkspaceViewModel
    @ObservedObject private var localization = WordZLocalization.shared
    @FocusedValue(\.workspaceCommandContext) private var commandContext
    @Environment(\.openWindow) private var openWindow

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
    }

    var body: some Commands {
        SidebarCommands()
        TextEditingCommands()

        CommandGroup(replacing: .appInfo) {
            Button(t("关于 WordZ", "About WordZ")) {
                openWindowRoute(.about)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(t("设置…", "Settings…")) {
                openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: [.command])
        }

        CommandGroup(replacing: .newItem) {
            Button(t("新建工作区", "New Workspace")) {
                performAsyncCommand("newWorkspace") {
                    await workspace.newWorkspace()
                }
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button(t("恢复已保存工作区", "Restore Saved Workspace")) {
                performAsyncCommand("restoreWorkspace") {
                    await workspace.restoreSavedWorkspace()
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!workspace.canRestoreWorkspace)

            Button(t("显示欢迎页", "Show Welcome")) {
                logCommand("showWelcome")
                workspace.presentWelcome()
            }
            .keyboardShortcut("/", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .importExport) {
            Button(t("导入语料…", "Import Corpora…")) {
                performFocusedCommand("importCorpora") { context in
                    await importCorpora(using: context)
                }
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(!isContextEnabled(\.canImportCorpora))

            Button(t("打开已选语料", "Open Selected Corpus")) {
                performFocusedCommand("openSelectedCorpus") { context in
                    await openSelectedCorpus(using: context)
                }
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
            .disabled(!isContextEnabled(\.canOpenSelectedCorpus))

            Button(t("打开 DB 来源预览", "Open DB Source Preview")) {
                performFocusedCommand("openSourceView") { context in
                    await openSourceView(using: context)
                }
            }
            .disabled(!isContextEnabled(\.canOpenSourceView))

            Button(t("快速预览当前内容", "Quick Look Current Content")) {
                performFocusedCommand("quickLookContent") { context in
                    await quickLookContent(using: context)
                }
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])
            .disabled(!isContextEnabled(\.canQuickLookContent))

            Button(t("分享当前内容", "Share Current Content")) {
                performFocusedCommand("shareContent") { context in
                    await shareContent(using: context)
                }
            }
            .disabled(!isContextEnabled(\.canShareContent))

            Divider()

            Button(t("复制当前结果", "Copy Current Result")) {
                performFocusedCommand("copyCurrentResult") { context in
                    await copyCurrentResult(using: context)
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!isContextEnabled(\.canCopyCurrentResult))

            Button(t("导出当前结果…", "Export Current Result…")) {
                performFocusedCommand("exportCurrent") { context in
                    await exportCurrent(using: context)
                }
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!isContextEnabled(\.canExportCurrent))

            Divider()

            Menu(t("最近打开", "Recent Documents")) {
                if recentDocuments.isEmpty {
                    Button(t("没有最近打开记录", "No recent documents")) { }
                        .disabled(true)
                } else {
                    ForEach(recentDocuments) { item in
                        Button(item.title) {
                            performAsyncCommand("openRecentDocument") {
                                await workspace.openRecentDocument(item.corpusID)
                            }
                        }
                    }
                    Divider()
                    Button(t("清空最近打开", "Clear Recent Documents")) {
                        performAsyncCommand("clearRecentDocuments") {
                            await workspace.clearRecentDocuments()
                        }
                    }
                }
            }
            .disabled(recentDocuments.isEmpty)
        }

        CommandGroup(after: .sidebar) {
            Divider()

            Button(t("刷新工作区", "Refresh Workspace")) {
                performFocusedCommand("refreshWorkspace") { context in
                    await refreshWorkspace(using: context)
                }
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!isContextEnabled(\.canRefreshWorkspace))

            Divider()

            Toggle(isOn: inspectorVisibilityBinding) {
                Text(t("显示检查器", "Show Inspector"))
            }
            .disabled(!isContextEnabled(\.canToggleInspector))

            Divider()

            Picker(t("页面", "Page"), selection: selectedMainRouteBinding) {
                ForEach(WorkspaceFeatureRegistry.descriptors.filter(\.showsInPagePicker)) { descriptor in
                    Text(descriptor.title(in: localization.effectiveMode))
                        .tag(descriptor.route)
                }
            }
            .disabled(!isContextEnabled(\.canSelectMainRoute))
        }

        CommandGroup(after: .windowArrangement) {
            Divider()

            windowButton(.library)
                .keyboardShortcut("1", modifiers: [.command])

            windowButton(.taskCenter)
                .keyboardShortcut("2", modifiers: [.command])
        }

        CommandMenu(t("分析", "Analysis")) {
            ForEach(WorkspaceFeatureRegistry.commandDescriptors) { descriptor in
                if let action = descriptor.commandAction {
                    analysisCommand(descriptor.title(in: localization.effectiveMode), action: action)
                }
            }

            Divider()

            Button(t("保存当前分析预设…", "Save Current Analysis Preset…")) {
                performFocusedCommand("saveAnalysisPreset") { context in
                    await saveAnalysisPreset(using: context)
                }
            }
            .disabled(!isContextEnabled(\.canSaveAnalysisPreset))

            Menu(t("应用分析预设", "Apply Analysis Preset")) {
                if workspace.analysisPresets.isEmpty {
                    Button(t("还没有已保存预设", "No saved presets yet")) { }
                        .disabled(true)
                } else {
                    ForEach(workspace.analysisPresets) { preset in
                        Button("\(preset.name) · \(preset.summary(in: localization.effectiveMode))") {
                            performFocusedCommand("applyAnalysisPreset") { context in
                                await applyAnalysisPreset(preset.id, using: context)
                            }
                        }
                    }
                }
            }
            .disabled(!isContextEnabled(\.canManageAnalysisPresets) || workspace.analysisPresets.isEmpty)

            Menu(t("删除分析预设", "Delete Analysis Preset")) {
                if workspace.analysisPresets.isEmpty {
                    Button(t("还没有已保存预设", "No saved presets yet")) { }
                        .disabled(true)
                } else {
                    ForEach(workspace.analysisPresets) { preset in
                        Button(preset.name, role: .destructive) {
                            performFocusedCommand("deleteAnalysisPreset") { context in
                                await deleteAnalysisPreset(preset.id, using: context)
                            }
                        }
                    }
                }
            }
            .disabled(!isContextEnabled(\.canManageAnalysisPresets) || workspace.analysisPresets.isEmpty)

            Divider()

            Button(t("导出分析材料包…", "Export Analysis Materials Bundle…")) {
                performFocusedCommand("exportReportBundle") { context in
                    await exportReportBundle(using: context)
                }
            }
            .disabled(!isContextEnabled(\.canExportReportBundle))
        }

        dossierAndAnnotationCommands
    }

    @CommandsBuilder
    private var dossierAndAnnotationCommands: some Commands {
        CommandMenu(t("证据", "Evidence")) {
            Button(t("保存保留摘录为文本…", "Save Kept Excerpts as Text…")) {
                performFocusedCommand("exportEvidenceDossier") { context in
                    await exportEvidenceDossier(using: context)
                }
            }
            .disabled(!isContextEnabled(\.canExportEvidenceDossier))
        }

        annotationAndHelpCommands
    }

    @CommandsBuilder
    private var annotationAndHelpCommands: some Commands {
        CommandMenu(t("标注显示", "Annotation Display")) {
            Section(t("显示口径", "Display Profile")) {
                ForEach(WorkspaceAnnotationProfile.allCases) { profile in
                    Button(profile.title(in: localization.effectiveMode)) {
                        workspace.setAnnotationProfile(profile)
                    }
                    .disabled(!annotationCommandsEnabled)
                }
            }

            Divider()

            Menu(t("文字范围", "Script Scope")) {
                ForEach(TokenScript.allCases) { script in
                    Button {
                        workspace.toggleAnnotationScript(script)
                    } label: {
                        if workspace.annotationState.scriptSet.contains(script) {
                            Label(script.title(in: localization.effectiveMode), systemImage: "checkmark")
                        } else {
                            Text(script.title(in: localization.effectiveMode))
                        }
                    }
                    .disabled(!annotationCommandsEnabled)
                }
            }

            Menu(t("词类筛选", "Part-of-Speech Filter")) {
                ForEach(TokenLexicalClass.allCases) { lexicalClass in
                    Button {
                        workspace.toggleAnnotationLexicalClass(lexicalClass)
                    } label: {
                        if workspace.annotationState.lexicalClassSet.contains(lexicalClass) {
                            Label(lexicalClass.title(in: localization.effectiveMode), systemImage: "checkmark")
                        } else {
                            Text(lexicalClass.title(in: localization.effectiveMode))
                        }
                    }
                    .disabled(!annotationCommandsEnabled)
                }
            }

            Divider()

            Button(t("清空显示筛选", "Clear Display Filters")) {
                workspace.clearAnnotationFilters()
            }
            .disabled(!annotationCommandsEnabled || (workspace.annotationState.lexicalClasses.isEmpty && workspace.annotationState.scripts.isEmpty))
        }

        CommandGroup(replacing: .help) {
            Button(t("使用指南", "Usage Guide")) {
                openWindowRoute(.help)
            }

            Button(t("版本说明", "Release Notes")) {
                openWindowRoute(.releaseNotes)
            }

            Divider()

            Button(t("检查更新…", "Check for Updates…")) {
                performAsyncCommand("checkForUpdates") {
                    await workspace.checkForUpdatesNow()
                }
            }

            if workspace.settings.scene.canDownloadUpdate || workspace.settings.scene.canInstallDownloadedUpdate || workspace.settings.scene.isDownloadingUpdate {
                Button(t("打开更新窗口", "Open Update Window")) {
                    openWindowRoute(.updatePrompt)
                }
            }

            if workspace.settings.scene.canDownloadUpdate {
                Button(t("下载更新", "Download Update")) {
                    performAsyncCommand("downloadUpdate", route: .updatePrompt) {
                        await workspace.downloadLatestUpdate()
                    }
                }
            }

            if workspace.settings.scene.canInstallDownloadedUpdate {
                Button(t("安装已下载更新", "Install Downloaded Update")) {
                    performAsyncCommand("installDownloadedUpdate", route: .updatePrompt) {
                        await workspace.installDownloadedUpdate()
                    }
                }
                Button(t("在 Finder 中显示已下载更新", "Reveal Downloaded Update in Finder")) {
                    performAsyncCommand("revealDownloadedUpdate", route: .updatePrompt) {
                        await workspace.revealDownloadedUpdate()
                    }
                }
            }
            Button(t("导出诊断包…", "Export Diagnostics Bundle…")) {
                performAsyncCommand("exportDiagnostics") {
                    await workspace.exportDiagnostics()
                }
            }

            Divider()

            Button(t("项目主页", "Project Home")) {
                performAsyncCommand("openProjectHome") {
                    await workspace.openProjectHome()
                }
            }
            Button(t("GitHub 反馈", "GitHub Feedback")) {
                performAsyncCommand("openFeedback") {
                    await workspace.openFeedback()
                }
            }
        }
    }

    private var recentDocuments: [RecentDocumentItem] {
        workspace.settings.scene.recentDocuments
    }

    private var toolbarCommandContext: WorkspaceCommandContext? {
        guard let commandContext, commandContext.supportsWorkspaceCommands else {
            return nil
        }
        return commandContext
    }

    private var inspectorVisibilityBinding: Binding<Bool> {
        Binding(
            get: { commandContext?.isInspectorPresented ?? false },
            set: { isPresented in
                guard
                    let commandContext,
                    commandContext.canToggleInspector,
                    commandContext.isInspectorPresented != isPresented
                else { return }
                postCommand(.toggleInspector, name: "toggleInspector")
            }
        )
    }

    private var selectedMainRouteBinding: Binding<WorkspaceMainRoute> {
        Binding(
            get: { commandContext?.selectedMainRoute ?? .stats },
            set: { nextRoute in
                guard
                    let commandContext,
                    commandContext.canSelectMainRoute,
                    commandContext.selectedMainRoute != nextRoute
                else { return }
                logCommand("selectMainRoute.\(nextRoute.rawValue)", route: commandContext.route)
                workspace.selectedRoute = nextRoute
            }
        )
    }

    private func isContextEnabled(_ keyPath: KeyPath<WorkspaceCommandContext, Bool>) -> Bool {
        commandContext?[keyPath: keyPath] ?? false
    }

    private func isEnabled(_ action: WorkspaceToolbarAction) -> Bool {
        toolbarCommandContext?.toolbar?.item(for: action)?.isEnabled ?? false
    }

    private var annotationCommandsEnabled: Bool {
        commandContext?.canConfigureAnnotation ?? false
    }

    private func analysisCommand(_ title: String, action: WorkspaceToolbarAction) -> some View {
        Button(title) {
            postCommand(action.nativeCommand, name: action.rawValue)
        }
        .disabled(!isEnabled(action))
    }

    private func windowButton(_ route: NativeWindowRoute) -> some View {
        Button(route.title(in: localization.effectiveMode)) {
            openWindowRoute(route)
        }
    }

    private func logCommand(_ name: String, route: NativeWindowRoute? = nil) {
        let routeLabel = route?.id ?? commandContext?.route.id ?? "global"
        commandLogger.info("command=\(name, privacy: .public) route=\(routeLabel, privacy: .public)")
    }

    private func performAsyncCommand(
        _ name: String,
        route: NativeWindowRoute? = nil,
        _ operation: @escaping @MainActor () async -> Void
    ) {
        logCommand(name, route: route)
        Task { await operation() }
    }

    private func performFocusedCommand(
        _ name: String,
        _ operation: @escaping @MainActor (WorkspaceCommandContext) async -> Void
    ) {
        guard let commandContext else { return }
        logCommand(name, route: commandContext.route)
        Task { await operation(commandContext) }
    }

    private func postCommand(_ command: NativeAppCommand, name: String? = nil) {
        logCommand(name ?? command.rawValue)
        NativeAppCommandCenter.post(command)
    }

    private func refreshWorkspace(using context: WorkspaceCommandContext) async {
        guard context.canRefreshWorkspace else { return }
        await workspace.refreshAll()
    }

    private func importCorpora(using context: WorkspaceCommandContext) async {
        guard context.canImportCorpora else { return }
        await workspace.importCorpusFromDialog(preferredWindowRoute: context.route)
    }

    private func openSelectedCorpus(using context: WorkspaceCommandContext) async {
        guard context.canOpenSelectedCorpus else { return }
        await workspace.openSelectedCorpus()
    }

    private func openSourceView(using context: WorkspaceCommandContext) async {
        guard context.canOpenSourceView else { return }
        guard await workspace.performResultArtifactAction(.openSourceReader, preferredWindowRoute: context.route) else { return }
        openWindowRoute(.sourceReader)
    }

    private func quickLookContent(using context: WorkspaceCommandContext) async {
        guard context.canQuickLookContent else { return }
        switch context.route {
        case .library:
            await workspace.quickLookSelectedCorpus()
        default:
            await workspace.performResultArtifactAction(.preview, preferredWindowRoute: context.route)
        }
    }

    private func shareContent(using context: WorkspaceCommandContext) async {
        guard context.canShareContent else { return }
        switch context.route {
        case .library:
            await workspace.shareSelectedCorpus()
        default:
            await workspace.performResultArtifactAction(.share, preferredWindowRoute: context.route)
        }
    }

    private func copyCurrentResult(using context: WorkspaceCommandContext) async {
        guard context.canCopyCurrentResult else { return }
        await workspace.performResultArtifactAction(.copy, preferredWindowRoute: context.route)
    }

    private func exportCurrent(using context: WorkspaceCommandContext) async {
        guard context.canExportCurrent else { return }
        await workspace.performResultArtifactAction(.export, preferredWindowRoute: context.route)
    }

    private func exportEvidenceDossier(using context: WorkspaceCommandContext) async {
        guard context.canExportEvidenceDossier else { return }
        await workspace.exportEvidencePacketMarkdown(preferredWindowRoute: context.route)
    }

    private func exportEvidenceJSON(using context: WorkspaceCommandContext) async {
        guard context.canExportEvidenceJSON else { return }
        await workspace.exportEvidenceJSON(preferredWindowRoute: context.route)
    }

    private func saveAnalysisPreset(using context: WorkspaceCommandContext) async {
        guard context.canSaveAnalysisPreset else { return }
        await workspace.saveCurrentAnalysisPreset(preferredWindowRoute: context.route)
    }

    private func applyAnalysisPreset(_ presetID: String, using context: WorkspaceCommandContext) async {
        guard context.canManageAnalysisPresets else { return }
        await workspace.applyAnalysisPreset(presetID)
    }

    private func deleteAnalysisPreset(_ presetID: String, using context: WorkspaceCommandContext) async {
        guard context.canManageAnalysisPresets else { return }
        await workspace.deleteAnalysisPreset(presetID, preferredWindowRoute: context.route)
    }

    private func exportReportBundle(using context: WorkspaceCommandContext) async {
        guard context.canExportReportBundle else { return }
        await workspace.exportCurrentReportBundle(preferredWindowRoute: context.route)
    }

    private func openSettingsWindow() {
        logCommand("openSettings", route: .settings)
        NativeSettingsSupport.openSettingsWindow()
    }

    private func openWindowRoute(_ route: NativeWindowRoute) {
        logCommand("openWindow", route: route)
        guard NativeWindowRouting.shouldRequestPresentation(for: route) else { return }
        openWindow(id: route.id)
    }

    private func t(_ zh: String, _ en: String) -> String {
        localization.text(zh, en)
    }
}
