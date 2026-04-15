import AppKit
import Foundation

@MainActor
package enum NativeWindowRouting {
    private final class WeakWindowBox {
        weak var window: NSWindow?

        init(window: NSWindow?) {
            self.window = window
        }
    }

    private static var registeredWindows: [NativeWindowRoute: WeakWindowBox] = [:]

    package static func identifier(for route: NativeWindowRoute) -> NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(route.id)
    }

    package static func register(_ window: NSWindow?, for route: NativeWindowRoute) {
        guard let window else {
            registeredWindows[route] = nil
            return
        }
        registeredWindows[route] = WeakWindowBox(window: window)
        window.identifier = identifier(for: route)
    }

    package static func window(for route: NativeWindowRoute) -> NSWindow? {
        if let window = registeredWindows[route]?.window {
            return window
        }
        let application = NSApplication.shared
        let identifier = identifier(for: route)
        let window = application.windows.first { $0.identifier == identifier }
        if let window {
            registeredWindows[route] = WeakWindowBox(window: window)
        }
        return window
    }

    package static func isActive(_ route: NativeWindowRoute) -> Bool {
        let application = NSApplication.shared
        let identifier = identifier(for: route)
        return application.keyWindow?.identifier == identifier || application.mainWindow?.identifier == identifier
    }

    package static func presentationWindow(preferredRoute: NativeWindowRoute?) -> NSWindow? {
        resolvePresentationWindow(
            preferredRoute: preferredRoute,
            keyWindow: NSApplication.shared.keyWindow,
            mainWindow: NSApplication.shared.mainWindow,
            fallbackWindows: fallbackWindows()
        )
    }

    package static func resolvePresentationWindow(
        preferredRoute: NativeWindowRoute?,
        keyWindow: NSWindow?,
        mainWindow: NSWindow?,
        fallbackWindows: [NSWindow]
    ) -> NSWindow? {
        if let keyWindow {
            return keyWindow
        }
        if let mainWindow {
            return mainWindow
        }
        if let preferredRoute, let preferredWindow = fallbackWindows.first(where: { $0.identifier == identifier(for: preferredRoute) }) {
            return preferredWindow
        }
        if let mainWorkspaceWindow = fallbackWindows.first(where: { $0.identifier == identifier(for: .mainWorkspace) }) {
            return mainWorkspaceWindow
        }
        return fallbackWindows.first
    }

    package static func waitUntilActive(
        _ route: NativeWindowRoute,
        attempts: Int = 12,
        sleepNanoseconds: UInt64 = 16_000_000
    ) async -> NSWindow? {
        for attempt in 0..<attempts {
            if let window = window(for: route), (isActive(route) || window.isVisible || attempt > 0) {
                return window
            }
            await Task.yield()
            if attempt < attempts - 1 {
                try? await Task.sleep(nanoseconds: sleepNanoseconds)
            }
        }
        return window(for: route)
    }

    private static func fallbackWindows() -> [NSWindow] {
        let registered = registeredWindows.values.compactMap(\.window).filter(\.isVisible)
        var seenIdentifiers = Set<ObjectIdentifier>()
        let visibleRegistered = registered.filter { window in
            seenIdentifiers.insert(ObjectIdentifier(window)).inserted
        }
        if !visibleRegistered.isEmpty {
            return visibleRegistered
        }
        return NSApplication.shared.windows.filter { $0.identifier != nil && $0.isVisible }
    }
}
