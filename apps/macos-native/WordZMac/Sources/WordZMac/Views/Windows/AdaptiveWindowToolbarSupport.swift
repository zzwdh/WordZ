import SwiftUI

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
                    systemImage: WorkspaceToolbarAction.refresh.toolbarSymbolName,
                    help: refreshItem.title,
                    isEnabled: refreshItem.isEnabled,
                    action: { onPostCommand(.refreshWorkspace) }
                )
            }
        }

        AdaptiveToolbarSpacer()

        ToolbarItemGroup(placement: .primaryAction) {
            if let openSelectedItem = toolbar.item(for: .openSelected) {
                toolbarButton(
                    title: openSelectedItem.title,
                    systemImage: WorkspaceToolbarAction.openSelected.toolbarSymbolName,
                    help: openSelectedItem.title,
                    isEnabled: openSelectedItem.isEnabled,
                    action: { onPostCommand(.openSelectedCorpus) }
                )
            }

            if let openSourceReaderItem = toolbar.item(for: .openSourceReader) {
                toolbarButton(
                    title: openSourceReaderItem.title,
                    systemImage: WorkspaceToolbarAction.openSourceReader.toolbarSymbolName,
                    help: openSourceReaderItem.title,
                    isEnabled: openSourceReaderItem.isEnabled,
                    action: { onPostCommand(.openSourceReader) }
                )
            }

            if let annotationItem = toolbar.item(for: .annotationControls) {
                annotationToolbarMenu(title: annotationItem.title, isEnabled: annotationItem.isEnabled)
            }

            toolbarButton(
                title: wordZText("运行", "Run", mode: languageMode),
                systemImage: "play.fill",
                help: wordZText("运行当前分析：", "Run current analysis: ", mode: languageMode) + selectedRoute.displayTitle(in: languageMode),
                isEnabled: selectedRoute.toolbarRunAction.flatMap { toolbar.item(for: $0)?.isEnabled } ?? false,
                action: {
                    guard let command = selectedRoute.toolbarRunAction?.nativeCommand else { return }
                    onPostCommand(command)
                }
            )

            if let exportItem = toolbar.item(for: .exportCurrent) {
                toolbarButton(
                    title: exportItem.title,
                    systemImage: WorkspaceToolbarAction.exportCurrent.toolbarSymbolName,
                    help: exportItem.title,
                    isEnabled: exportItem.isEnabled,
                    action: { onPostCommand(.exportCurrent) }
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .help(help)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    private func annotationToolbarMenu(title: String, isEnabled: Bool) -> some View {
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
            Image(systemName: WorkspaceToolbarAction.annotationControls.toolbarSymbolName)
        }
        .help("\(title)\n\(annotationSummary)")
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}

struct LibraryWindowToolbar: ToolbarContent {
    @Binding var preserveHierarchy: Bool
    let languageMode: AppLanguageMode
    let canTriggerCleaning: Bool
    let cleaningToolbarTitle: String
    let cleaningToolbarAction: LibraryManagementAction
    let overflowActions: [LibraryManagementOverflowActionSceneItem]
    let onAction: (LibraryManagementAction) -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(wordZText("导入语料", "Import Corpora", mode: languageMode)) {
                onAction(.importPaths)
            }

            Button(cleaningToolbarTitle) {
                onAction(cleaningToolbarAction)
            }
            .disabled(!canTriggerCleaning)

        }

        AdaptiveToolbarSpacer()

        if #available(macOS 26.0, *), NativePlatformCapabilities.current.supportsToolbarSearchEnhancements {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Toggle(wordZText("保留目录结构", "Preserve Folder Structure", mode: languageMode), isOn: $preserveHierarchy)

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
                    Toggle(wordZText("保留目录结构", "Preserve Folder Structure", mode: languageMode), isOn: $preserveHierarchy)

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

        if #available(macOS 26.0, *), NativePlatformCapabilities.current.supportsToolbarSearchEnhancements {
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
        if #available(macOS 26.0, *), NativePlatformCapabilities.current.supportsToolbarSearchEnhancements {
            ToolbarSpacer(.fixed)
        }
    }
}

struct NativeLibrarySearchPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        let capabilities = NativePlatformCapabilities.current
        let profile = NativeWindowPresentationProfile.profile(for: .library)

        if #available(macOS 26.0, *),
           profile.resolvedSearchMode(capabilities: capabilities) == .libraryToolbar {
            content.searchToolbarBehavior(.automatic)
        } else {
            content
        }
    }
}

struct NativeTaskCenterSearchPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        let capabilities = NativePlatformCapabilities.current
        let profile = NativeWindowPresentationProfile.profile(for: .taskCenter)

        if #available(macOS 26.0, *),
           profile.resolvedSearchMode(capabilities: capabilities) == .taskCenterToolbar {
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

    func nativeTaskCenterSearchPresentation() -> some View {
        modifier(NativeTaskCenterSearchPresentationModifier())
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
