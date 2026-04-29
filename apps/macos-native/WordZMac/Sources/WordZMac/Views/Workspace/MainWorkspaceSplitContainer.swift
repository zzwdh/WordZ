import AppKit
import SwiftUI

private let workspaceSplitLayoutAnimationDuration: TimeInterval = 0.18

struct WorkspaceSplitLayout: Equatable {
    var isSidebarVisible: Bool
    var isInspectorVisible: Bool
}

struct MainWorkspaceSplitContainer<Sidebar: View, Detail: View, Inspector: View>: NSViewControllerRepresentable {
    @Binding var isSidebarVisible: Bool
    @Binding var isInspectorVisible: Bool

    let sidebar: Sidebar
    let detail: Detail
    let inspector: Inspector
    let topAccessory: AnyView?

    init(
        isSidebarVisible: Binding<Bool>,
        isInspectorVisible: Binding<Bool>,
        topAccessory: AnyView? = nil,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail,
        @ViewBuilder inspector: () -> Inspector
    ) {
        _isSidebarVisible = isSidebarVisible
        _isInspectorVisible = isInspectorVisible
        self.sidebar = sidebar()
        self.detail = detail()
        self.inspector = inspector()
        self.topAccessory = topAccessory
    }

    func makeNSViewController(context: Context) -> MainWorkspaceSplitController<Sidebar, Detail, Inspector> {
        MainWorkspaceSplitController(
            sidebar: sidebar,
            detail: detail,
            inspector: inspector,
            topAccessory: topAccessory
        )
    }

    func updateNSViewController(
        _ controller: MainWorkspaceSplitController<Sidebar, Detail, Inspector>,
        context: Context
    ) {
        controller.update(
            sidebar: sidebar,
            detail: detail,
            inspector: inspector,
            topAccessory: topAccessory,
            layout: layout
        )
    }

    private var layout: WorkspaceSplitLayout {
        WorkspaceSplitLayout(
            isSidebarVisible: isSidebarVisible,
            isInspectorVisible: isInspectorVisible
        )
    }
}

final class MainWorkspaceSplitController<Sidebar: View, Detail: View, Inspector: View>: NSSplitViewController {
    private let sidebarController: HostedPaneViewController<Sidebar>
    private let detailController: HostedPaneViewController<Detail>
    private let inspectorController: HostedPaneViewController<Inspector>

    private let sidebarItem: NSSplitViewItem
    private let detailItem: NSSplitViewItem
    private let inspectorItem: NSSplitViewItem
    private var topAccessory: AnyView?
    private var detailAccessoryController: NSViewController?

    private var currentLayout = WorkspaceSplitLayout(
        isSidebarVisible: true,
        isInspectorVisible: true
    )
    private var hasAppliedInitialLayout = false

    init(sidebar: Sidebar, detail: Detail, inspector: Inspector, topAccessory: AnyView? = nil) {
        sidebarController = HostedPaneViewController(rootView: sidebar)
        detailController = HostedPaneViewController(rootView: detail)
        inspectorController = HostedPaneViewController(rootView: inspector)
        self.topAccessory = topAccessory

        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        detailItem = NSSplitViewItem(viewController: detailController)
        inspectorItem = NSSplitViewItem(viewController: inspectorController)

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self

        sidebarItem.canCollapse = true
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 360
        sidebarItem.holdingPriority = .defaultHigh

        detailItem.minimumThickness = 520

        inspectorItem.canCollapse = true
        inspectorItem.minimumThickness = 280
        inspectorItem.maximumThickness = 420
        inspectorItem.holdingPriority = .defaultHigh

        addSplitViewItem(sidebarItem)
        addSplitViewItem(detailItem)
        addSplitViewItem(inspectorItem)

        sidebarItem.preferredThicknessFraction = 0.24
        inspectorItem.preferredThicknessFraction = 0.26

        if NativePlatformCapabilities.current.supportsSplitViewAccessories {
            if #available(macOS 26.0, *) {
                sidebarItem.automaticallyAdjustsSafeAreaInsets = true
                detailItem.automaticallyAdjustsSafeAreaInsets = true
                inspectorItem.automaticallyAdjustsSafeAreaInsets = true
                updateTopAccessoryIfNeeded()
            }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyLayout(force: true, animated: false)
        hasAppliedInitialLayout = true
    }

    func update(
        sidebar: Sidebar,
        detail: Detail,
        inspector: Inspector,
        topAccessory: AnyView? = nil,
        layout: WorkspaceSplitLayout,
        animateLayoutChanges: Bool? = nil
    ) {
        sidebarController.update(rootView: sidebar)
        detailController.update(rootView: detail)
        inspectorController.update(rootView: inspector)
        self.topAccessory = topAccessory
        if NativePlatformCapabilities.current.supportsSplitViewAccessories {
            if #available(macOS 26.0, *) {
                updateTopAccessoryIfNeeded()
            }
        }
        guard currentLayout != layout else { return }
        currentLayout = layout
        applyLayout(animated: animateLayoutChanges ?? hasAppliedInitialLayout)
    }

    private func applyLayout(force: Bool = false, animated: Bool = false) {
        guard isViewLoaded else { return }

        applyVisibility(
            currentLayout.isSidebarVisible,
            to: sidebarItem,
            force: force,
            animated: animated
        )
        applyVisibility(
            currentLayout.isInspectorVisible,
            to: inspectorItem,
            force: force,
            animated: animated
        )
    }

    private func applyVisibility(
        _ isVisible: Bool,
        to item: NSSplitViewItem,
        force: Bool,
        animated: Bool
    ) {
        let shouldCollapse = !isVisible
        guard force || item.isCollapsed != shouldCollapse else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = workspaceSplitLayoutAnimationDuration
                context.allowsImplicitAnimation = true
                item.animator().isCollapsed = shouldCollapse
            }
        } else {
            item.isCollapsed = shouldCollapse
        }
    }

    @available(macOS 26.0, *)
    private func updateTopAccessoryIfNeeded() {
        if let topAccessory {
            if let detailAccessoryController = detailAccessoryController as? HostedSplitAccessoryViewController {
                detailAccessoryController.update(rootView: topAccessory)
            } else {
                let controller = HostedSplitAccessoryViewController(rootView: topAccessory)
                detailAccessoryController = controller
                detailItem.topAlignedAccessoryViewControllers = [controller]
            }
        } else {
            detailAccessoryController = nil
            detailItem.topAlignedAccessoryViewControllers = []
        }
    }
}

final class HostedPaneViewController<Content: View>: NSHostingController<Content> {
    override init(rootView: Content) {
        super.init(rootView: rootView)
        if #available(macOS 13.0, *) {
            sizingOptions = []
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(rootView: Content) {
        self.rootView = rootView
    }
}

@available(macOS 26.0, *)
final class HostedSplitAccessoryViewController: NSSplitViewItemAccessoryViewController {
    private let hostingController: NSHostingController<AnyView>

    init(rootView: AnyView) {
        hostingController = NSHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
        automaticallyAppliesContentInsets = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hostingController)
        let hostedView = hostingController.view
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostedView)

        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: view.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func update(rootView: AnyView) {
        hostingController.rootView = rootView
    }
}
