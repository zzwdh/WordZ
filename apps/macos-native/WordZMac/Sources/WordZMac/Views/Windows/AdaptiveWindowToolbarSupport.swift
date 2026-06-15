import SwiftUI

import WordZWindowing
import WordZShared
struct MainWorkspaceWindowToolbar: ToolbarContent {
    let toolbar: WorkspaceToolbarSceneModel
    let selectedRoute: WorkspaceMainRoute
    let languageMode: AppLanguageMode
    let annotationState: WorkspaceAnnotationState
    let annotationSummary: String
    let isSidebarVisible: Bool
    let isInspectorVisible: Bool
    let onToggleSidebar: () -> Void
    let onToggleInspector: () -> Void
    let onSelectAnnotationProfile: (WorkspaceAnnotationProfile) -> Void
    let onToggleAnnotationScript: (TokenScript) -> Void
    let onToggleAnnotationLexicalClass: (TokenLexicalClass) -> Void
    let onClearAnnotationFilters: () -> Void
    let onPostCommand: (NativeAppCommand) -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            toolbarButton(
                title: wordZText("侧栏", "Sidebar", mode: languageMode),
                systemImage: isSidebarVisible ? "sidebar.left" : "sidebar.right",
                help: wordZText("显示或隐藏侧栏", "Show or hide sidebar", mode: languageMode),
                action: onToggleSidebar
            )

            if let refreshItem = toolbar.item(for: .refresh) {
                toolbarButton(
                    title: refreshItem.title,
                    systemImage: refreshItem.systemImage,
                    help: refreshItem.title,
                    isEnabled: refreshItem.isEnabled,
                    action: {
                        guard let command = refreshItem.nativeCommand else { return }
                        onPostCommand(command)
                    }
                )
            }
        }

        AdaptiveToolbarSpacer()

        ToolbarItemGroup(placement: .primaryAction) {
            if let openSelectedItem = toolbar.item(for: .openSelected) {
                toolbarButton(
                    title: openSelectedItem.title,
                    systemImage: openSelectedItem.systemImage,
                    help: openSelectedItem.title,
                    isEnabled: openSelectedItem.isEnabled,
                    action: {
                        guard let command = openSelectedItem.nativeCommand else { return }
                        onPostCommand(command)
                    }
                )
            }

            if let openSourceReaderItem = toolbar.item(for: .openSourceReader) {
                toolbarButton(
                    title: openSourceReaderItem.title,
                    systemImage: openSourceReaderItem.systemImage,
                    help: openSourceReaderItem.title,
                    isEnabled: openSourceReaderItem.isEnabled,
                    action: {
                        guard let command = openSourceReaderItem.nativeCommand else { return }
                        onPostCommand(command)
                    }
                )
            }
        }

        AdaptiveToolbarSpacer()

        ToolbarItemGroup(placement: .primaryAction) {
            if let annotationItem = toolbar.item(for: .annotationControls) {
                annotationToolbarMenu(
                    title: annotationItem.title,
                    systemImage: annotationItem.systemImage,
                    isEnabled: annotationItem.isEnabled
                )
            }

            let runItem = selectedRoute.toolbarRunAction.flatMap { toolbar.item(for: $0) }
            toolbarButton(
                title: wordZText("运行", "Run", mode: languageMode),
                systemImage: runItem?.systemImage ?? "play.fill",
                help: wordZText("运行当前分析：", "Run current analysis: ", mode: languageMode) + selectedRoute.displayTitle(in: languageMode),
                isEnabled: runItem?.isEnabled ?? false,
                isProminent: true,
                action: {
                    guard let command = runItem?.nativeCommand else { return }
                    onPostCommand(command)
                }
            )
        }

        AdaptiveToolbarSpacer()

        ToolbarItemGroup(placement: .primaryAction) {
            if let copyItem = toolbar.item(for: .copyCurrentResult) {
                toolbarButton(
                    title: copyItem.title,
                    systemImage: copyItem.systemImage,
                    help: wordZText("复制当前结果，可直接粘贴到 Excel", "Copy current result for pasting into Excel", mode: languageMode),
                    isEnabled: copyItem.isEnabled,
                    action: {
                        guard let command = copyItem.nativeCommand else { return }
                        onPostCommand(command)
                    }
                )
            }

            if let exportItem = toolbar.item(for: .exportCurrent) {
                toolbarButton(
                    title: exportItem.title,
                    systemImage: exportItem.systemImage,
                    help: exportItem.title,
                    isEnabled: exportItem.isEnabled,
                    isProminent: true,
                    action: {
                        guard let command = exportItem.nativeCommand else { return }
                        onPostCommand(command)
                    }
                )
            }

            toolbarButton(
                title: wordZText("检查器", "Inspector", mode: languageMode),
                systemImage: "sidebar.right",
                help: isInspectorVisible
                    ? wordZText("隐藏检查器", "Hide inspector", mode: languageMode)
                    : wordZText("显示检查器", "Show inspector", mode: languageMode),
                action: onToggleInspector
            )
        }
    }

    private func toolbarButton(
        title: String,
        systemImage: String,
        help: String,
        isEnabled: Bool = true,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .adaptiveGlassButtonStyle(prominent: isProminent)
        .help(help)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    private func annotationToolbarMenu(
        title: String,
        systemImage: String,
        isEnabled: Bool
    ) -> some View {
        Menu {
            Section(wordZText("显示口径", "Display Profile", mode: languageMode)) {
                ForEach(WorkspaceAnnotationProfile.allCases) { profile in
                    Button {
                        onSelectAnnotationProfile(profile)
                    } label: {
                        if annotationState.profile == profile {
                            Label(profile.title(in: languageMode), systemImage: "checkmark")
                        } else {
                            Text(profile.title(in: languageMode))
                        }
                    }
                }
            }

            Section(wordZText("文字范围", "Script Scope", mode: languageMode)) {
                ForEach(TokenScript.allCases) { script in
                    Button {
                        onToggleAnnotationScript(script)
                    } label: {
                        if annotationState.scriptSet.contains(script) {
                            Label(script.title(in: languageMode), systemImage: "checkmark")
                        } else {
                            Text(script.title(in: languageMode))
                        }
                    }
                }
            }

            Section(wordZText("词类筛选", "Part-of-Speech Filter", mode: languageMode)) {
                ForEach(TokenLexicalClass.allCases) { lexicalClass in
                    Button {
                        onToggleAnnotationLexicalClass(lexicalClass)
                    } label: {
                        if annotationState.lexicalClassSet.contains(lexicalClass) {
                            Label(lexicalClass.title(in: languageMode), systemImage: "checkmark")
                        } else {
                            Text(lexicalClass.title(in: languageMode))
                        }
                    }
                }
            }

            Divider()

            Button(wordZText("清空显示筛选", "Clear Display Filters", mode: languageMode)) {
                onClearAnnotationFilters()
            }
            .disabled(annotationState.lexicalClasses.isEmpty && annotationState.scripts.isEmpty)
        } label: {
            Image(systemName: systemImage)
        }
        .help("\(title)\n\(annotationSummary)")
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .adaptiveGlassButtonStyle()
    }
}

struct LibraryWindowToolbar: ToolbarContent {
    @Binding var preserveHierarchy: Bool
    let languageMode: AppLanguageMode
    let canTriggerCleaning: Bool
    let cleaningToolbarTitle: String
    let cleaningToolbarAction: LibraryManagementAction
    let status: LibraryToolbarStatus?
    let overflowActions: [LibraryManagementOverflowActionSceneItem]
    let onAction: (LibraryManagementAction) -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            toolbarButton(
                title: wordZText("添加文件", "Add Files", mode: languageMode),
                systemImage: "plus",
                isProminent: true,
                action: { onAction(.importPaths) }
            )

            toolbarButton(
                title: wordZText("新建文件夹", "New Folder", mode: languageMode),
                systemImage: "folder.badge.plus",
                action: { onAction(.createFolder) }
            )
        }

        AdaptiveToolbarSpacer()

        if let status {
            ToolbarItem(placement: .automatic) {
                libraryStatusView(status)
            }
        }

        AdaptiveToolbarSpacer()

        if #available(macOS 26.0, *), NativePlatformCapabilities.current.supportsToolbarSharedBackground {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(wordZText("导入语料", "Import Corpus", mode: languageMode)) {
                        onAction(.showCorpusBuilder)
                    }

                    Button(wordZText("保存当前选择为语料集", "Save Selection as Set", mode: languageMode)) {
                        onAction(.saveCurrentCorpusSet)
                    }

                    Divider()

                    ForEach(overflowActions) { item in
                        Button(item.title) {
                            onAction(item.action)
                        }
                    }
                } label: {
                    Label(wordZText("更多", "More", mode: languageMode), systemImage: "ellipsis.circle")
                }
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(wordZText("导入语料", "Import Corpus", mode: languageMode)) {
                        onAction(.showCorpusBuilder)
                    }

                    Button(wordZText("保存当前选择为语料集", "Save Selection as Set", mode: languageMode)) {
                        onAction(.saveCurrentCorpusSet)
                    }

                    Divider()

                    ForEach(overflowActions) { item in
                        Button(item.title) {
                            onAction(item.action)
                        }
                    }
                } label: {
                    Label(wordZText("更多", "More", mode: languageMode), systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private func toolbarButton(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .adaptiveGlassButtonStyle(prominent: isProminent)
        .help(title)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func libraryStatusView(_ status: LibraryToolbarStatus) -> some View {
        let content = HStack(spacing: 6) {
            Image(systemName: status.systemImage)
            if let progress = status.progress {
                ProgressView(value: progress)
                    .frame(width: 54)
            } else {
                Text(status.title)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundStyle(status.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(status.tint.opacity(0.12), in: Capsule())
        .help(status.detail)
        .accessibilityLabel(status.title)

        if status.badgeCount > 0 {
            content.badge(status.badgeCount)
        } else {
            content
        }
    }
}

struct LibraryToolbarStatus: Equatable {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let badgeCount: Int
    let progress: Double?
}

struct SettingsWindowToolbar: ToolbarContent {
    let languageMode: AppLanguageMode
    let onAction: (SettingsPaneAction) -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button(wordZText("立即检查更新", "Check Now", mode: languageMode)) {
                onAction(.checkForUpdatesNow)
            }
        }

        AdaptiveToolbarSpacer()

        if #available(macOS 26.0, *), NativePlatformCapabilities.current.supportsToolbarSharedBackground {
            ToolbarItem(placement: .primaryAction) {
                Button(wordZText("保存设置", "Save Settings", mode: languageMode)) {
                    onAction(.save)
                }
                .adaptiveProminentToolbarButtonStyle()
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button(wordZText("保存设置", "Save Settings", mode: languageMode)) {
                    onAction(.save)
                }
                .adaptiveProminentToolbarButtonStyle()
            }
        }
    }
}

struct AdaptiveToolbarSpacer: ToolbarContent {
    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(macOS 26.0, *), NativePlatformCapabilities.current.supportsToolbarSpacer {
            ToolbarSpacer(.fixed)
        }
    }
}

struct NativeLibrarySearchPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        let capabilities = NativePlatformCapabilities.current
        let profile = NativeWindowPresentationProfile.profile(for: .library)

        if #available(macOS 26.0, *),
           capabilities.supportsSearchToolbarBehavior,
           profile.resolvedSearchMode(capabilities: capabilities) == .libraryToolbar {
            content.searchToolbarBehavior(.automatic)
        } else {
            content
        }
    }
}

extension View {
    func nativeLibrarySearchPresentation() -> some View {
        modifier(NativeLibrarySearchPresentationModifier())
    }

    func adaptiveGlassButtonStyle(prominent: Bool = false) -> some View {
        modifier(AdaptiveGlassButtonStyleModifier(isProminent: prominent))
    }

    fileprivate func adaptiveProminentToolbarButtonStyle() -> some View {
        adaptiveGlassButtonStyle(prominent: true)
    }
}

private struct AdaptiveGlassButtonStyleModifier: ViewModifier {
    let isProminent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *),
           NativePlatformCapabilities.current.supportsGlassButtons {
            if isProminent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if isProminent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}
