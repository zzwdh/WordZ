import AppKit
import SwiftUI

@MainActor
final class NativeTaskCenterToolbarProgressCoordinator {
    private weak var window: NSWindow?
    private var accessoryController: NativeTaskCenterTitlebarAccessoryViewController?

    func bind(window: NSWindow?) {
        guard self.window !== window else { return }
        removeAccessory()
        self.window = window
    }

    func update(rootView: AnyView?) {
        guard NativePlatformCapabilities.current.supportsToolbarSearchEnhancements else {
            removeAccessory()
            return
        }
        guard let window, let rootView else {
            removeAccessory()
            return
        }

        if let accessoryController {
            accessoryController.update(rootView: rootView)
            return
        }

        let controller = NativeTaskCenterTitlebarAccessoryViewController(rootView: rootView)
        window.addTitlebarAccessoryViewController(controller)
        accessoryController = controller
    }

    func detach() {
        removeAccessory()
        window = nil
    }

    private func removeAccessory() {
        guard let accessoryController else { return }
        if let index = window?.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessoryController }) {
            window?.removeTitlebarAccessoryViewController(at: index)
        }
        self.accessoryController = nil
    }
}

@MainActor
private final class NativeTaskCenterTitlebarAccessoryViewController: NSTitlebarAccessoryViewController {
    private let hostingController: NSHostingController<AnyView>

    init(rootView: AnyView) {
        hostingController = NSHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
        layoutAttribute = .bottom
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
