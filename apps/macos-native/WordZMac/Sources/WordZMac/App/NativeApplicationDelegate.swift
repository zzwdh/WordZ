import AppKit
import Foundation

private let lifecycleLogger = WordZTelemetry.logger(category: "Lifecycle")

@MainActor
final class NativeApplicationDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var pendingOpenPaths: [String] = []
    private var presentWindow: ((NativeWindowRoute) -> Void)?
    private var pendingWindowRoute: NativeWindowRoute?

    func applicationDidFinishLaunching(_ notification: Notification) {
        lifecycleLogger.info("applicationDidFinishLaunching")
        NSApplication.shared.setActivationPolicy(.regular)
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        enqueue(paths: filenames)
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            presentWindowRoute(.mainWorkspace)
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func enqueue(paths: [String]) {
        let normalized = paths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !normalized.isEmpty else { return }
        pendingOpenPaths.append(contentsOf: normalized)
    }

    func consumePendingOpenPaths() -> [String] {
        let snapshot = pendingOpenPaths
        pendingOpenPaths = []
        return snapshot
    }

    func registerWindowPresenter(_ presenter: @escaping (NativeWindowRoute) -> Void) {
        presentWindow = presenter
        guard let pendingWindowRoute else { return }
        self.pendingWindowRoute = nil
        presenter(pendingWindowRoute)
    }

    func presentWindowRoute(_ route: NativeWindowRoute) {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        application.activate(ignoringOtherApps: true)

        if let window = NativeWindowRouting.window(for: route) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        if let presentWindow {
            presentWindow(route)
        } else {
            pendingWindowRoute = route
        }
    }
}
