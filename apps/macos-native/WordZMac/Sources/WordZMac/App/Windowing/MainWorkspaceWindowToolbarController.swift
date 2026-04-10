import AppKit
import Combine
import Foundation

@MainActor
final class MainWorkspaceWindowToolbarController: NSObject, ObservableObject, NSToolbarDelegate {
    private enum ItemIdentifier {
        static let toggleSidebar = NSToolbarItem.Identifier("wordz.main.toggleSidebar")
        static let refresh = NSToolbarItem.Identifier("wordz.main.refresh")
        static let openSelected = NSToolbarItem.Identifier("wordz.main.openSelected")
        static let runCurrent = NSToolbarItem.Identifier("wordz.main.runCurrent")
        static let exportCurrent = NSToolbarItem.Identifier("wordz.main.exportCurrent")
        static let toggleInspector = NSToolbarItem.Identifier("wordz.main.toggleInspector")
    }

    private let toolbarIdentifier = NSToolbar.Identifier("wordz.mainWorkspace.toolbar")

    private weak var window: NSWindow?
    private weak var workspace: MainWorkspaceViewModel?
    private var performShellAction: ((RootContentShellAction) -> Void)?
    private var performCommand: ((NativeAppCommand) -> Void)?
    private var sidebarVisibilityProvider: (() -> Bool)?
    private var inspectorVisibilityProvider: (() -> Bool)?
    private var observedShell: WorkspaceShellViewModel?
    private var shellObservation: AnyCancellable?
    private var localizationObservation: AnyCancellable?

    func attach(
        window: NSWindow?,
        workspace: MainWorkspaceViewModel,
        performShellAction: @escaping (RootContentShellAction) -> Void,
        performCommand: @escaping (NativeAppCommand) -> Void,
        isSidebarVisible: @escaping () -> Bool,
        isInspectorVisible: @escaping () -> Bool
    ) {
        self.window = window
        self.workspace = workspace
        self.performShellAction = performShellAction
        self.performCommand = performCommand
        sidebarVisibilityProvider = isSidebarVisible
        inspectorVisibilityProvider = isInspectorVisible

        observe(shell: workspace.shell)
        installToolbarIfNeeded(on: window)
        refreshToolbarItems()
    }

    func refreshToolbarItems() {
        guard let toolbar = window?.toolbar, toolbar.identifier == toolbarIdentifier else { return }
        toolbar.items.forEach(configure)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            ItemIdentifier.toggleSidebar,
            ItemIdentifier.refresh,
            ItemIdentifier.openSelected,
            ItemIdentifier.runCurrent,
            ItemIdentifier.exportCurrent,
            .flexibleSpace,
            ItemIdentifier.toggleInspector
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            ItemIdentifier.toggleSidebar,
            ItemIdentifier.refresh,
            ItemIdentifier.openSelected,
            ItemIdentifier.runCurrent,
            ItemIdentifier.exportCurrent,
            .flexibleSpace,
            ItemIdentifier.toggleInspector
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.isBordered = true
        item.target = self
        configure(item)
        return item
    }

    private func installToolbarIfNeeded(on window: NSWindow?) {
        guard let window else { return }
        if let toolbar = window.toolbar, toolbar.identifier == toolbarIdentifier {
            return
        }

        let toolbar = NSToolbar(identifier: toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .regular
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.showsBaselineSeparator = true

        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }

    private func observe(shell: WorkspaceShellViewModel) {
        guard observedShell !== shell else { return }
        observedShell = shell
        shellObservation = shell.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshToolbarItems()
                }
            }
        localizationObservation = WordZLocalization.shared.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshToolbarItems()
                }
            }
    }

    private func configure(_ item: NSToolbarItem) {
        switch item.itemIdentifier {
        case ItemIdentifier.toggleSidebar:
            configureToggleSidebar(item)
        case ItemIdentifier.refresh:
            configureCommandItem(item, action: .refresh)
        case ItemIdentifier.openSelected:
            configureCommandItem(item, action: .openSelected)
        case ItemIdentifier.runCurrent:
            configureRunCurrentItem(item)
        case ItemIdentifier.exportCurrent:
            configureCommandItem(item, action: .exportCurrent)
        case ItemIdentifier.toggleInspector:
            configureToggleInspector(item)
        default:
            break
        }
    }

    private func configureToggleSidebar(_ item: NSToolbarItem) {
        let mode = WordZLocalization.shared.effectiveMode
        let isVisible = sidebarVisibilityProvider?() ?? true
        let label = wordZText("侧栏", "Sidebar", mode: mode)
        item.label = label
        item.paletteLabel = label
        item.toolTip = wordZText("显示或隐藏侧栏", "Show or hide sidebar", mode: mode)
        item.image = symbolImage(
            named: isVisible ? "sidebar.left" : "sidebar.right",
            description: label
        )
        item.action = #selector(toggleSidebar)
    }

    private func configureToggleInspector(_ item: NSToolbarItem) {
        let mode = WordZLocalization.shared.effectiveMode
        let isVisible = inspectorVisibilityProvider?() ?? true
        let label = wordZText("检查器", "Inspector", mode: mode)
        item.label = label
        item.paletteLabel = label
        item.toolTip = isVisible
            ? wordZText("隐藏检查器", "Hide inspector", mode: mode)
            : wordZText("显示检查器", "Show inspector", mode: mode)
        item.image = symbolImage(named: "sidebar.right", description: label)
        item.action = #selector(toggleInspector)
    }

    private func configureCommandItem(_ item: NSToolbarItem, action: WorkspaceToolbarAction) {
        guard let actionItem = workspace?.shell.scene.toolbar.item(for: action) else {
            item.label = action.rawValue
            item.paletteLabel = action.rawValue
            item.toolTip = action.rawValue
            item.image = nil
            item.isEnabled = false
            item.action = nil
            return
        }

        item.label = actionItem.title
        item.paletteLabel = actionItem.title
        item.toolTip = actionItem.title
        item.isEnabled = actionItem.isEnabled
        item.image = symbolImage(named: symbolName(for: action), description: actionItem.title)
        item.action = selector(for: action)
    }

    private func configureRunCurrentItem(_ item: NSToolbarItem) {
        guard let workspace else {
            item.isEnabled = false
            item.action = nil
            return
        }

        let mode = WordZLocalization.shared.effectiveMode
        let route = workspace.selectedRoute
        let label = wordZText("运行", "Run", mode: mode)
        let tooltip = wordZText(
            "运行当前分析：",
            "Run current analysis: ",
            mode: mode
        ) + route.displayTitle(in: mode)
        let enabled = route.toolbarRunAction
            .flatMap { workspace.shell.scene.toolbar.item(for: $0)?.isEnabled }
            ?? false

        item.label = label
        item.paletteLabel = label
        item.toolTip = tooltip
        item.image = symbolImage(named: "play.fill", description: label)
        item.isEnabled = enabled
        item.action = #selector(runCurrentAnalysis)
    }

    private func symbolName(for action: WorkspaceToolbarAction) -> String {
        switch action {
        case .refresh:
            return "arrow.clockwise"
        case .showLibrary:
            return "books.vertical"
        case .openSelected:
            return "arrow.up.right.square"
        case .previewCurrentCorpus:
            return "space"
        case .shareCurrentContent:
            return "square.and.arrow.up"
        case .runStats, .runWord, .runTokenize, .runTopics, .runCompare, .runKeyword, .runChiSquare, .runNgram, .runKWIC, .runCollocate, .runLocator:
            return "play.fill"
        case .exportCurrent:
            return "square.and.arrow.up"
        }
    }

    private func selector(for action: WorkspaceToolbarAction) -> Selector? {
        switch action {
        case .refresh:
            return #selector(refreshWorkspace)
        case .openSelected:
            return #selector(openSelectedCorpus)
        case .exportCurrent:
            return #selector(exportCurrent)
        case .showLibrary, .previewCurrentCorpus, .shareCurrentContent,
             .runStats, .runWord, .runTokenize, .runTopics, .runCompare, .runKeyword,
             .runChiSquare, .runNgram, .runKWIC, .runCollocate, .runLocator:
            return nil
        }
    }

    private func symbolImage(named name: String, description: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: description)
    }

    @objc
    private func toggleSidebar() {
        performShellAction?(.toggleSidebar)
        refreshToolbarItems()
    }

    @objc
    private func refreshWorkspace() {
        performCommand?(.refreshWorkspace)
    }

    @objc
    private func openSelectedCorpus() {
        performCommand?(.openSelectedCorpus)
    }

    @objc
    private func runCurrentAnalysis() {
        guard let command = workspace?.selectedRoute.toolbarRunAction?.nativeCommand else { return }
        performCommand?(command)
    }

    @objc
    private func exportCurrent() {
        performCommand?(.exportCurrent)
    }

    @objc
    private func toggleInspector() {
        performShellAction?(.toggleInspector)
        refreshToolbarItems()
    }
}
