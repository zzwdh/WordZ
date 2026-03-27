import AppKit
import Foundation

@MainActor
final class NativeApplicationDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var pendingOpenPaths: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        enqueue(paths: filenames)
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
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
}
