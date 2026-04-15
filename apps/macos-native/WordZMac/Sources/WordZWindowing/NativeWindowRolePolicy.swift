import AppKit
import Foundation

package struct NativeWindowRolePolicy {
    package let route: NativeWindowRoute
    package let allowsRestoration: Bool
    package let allowsMinimize: Bool
    package let tabbingMode: NSWindow.TabbingMode

    package static func policy(for route: NativeWindowRoute) -> NativeWindowRolePolicy {
        switch route {
        case .mainWorkspace:
            return NativeWindowRolePolicy(
                route: route,
                allowsRestoration: true,
                allowsMinimize: true,
                tabbingMode: .disallowed
            )
        case .library:
            return NativeWindowRolePolicy(
                route: route,
                allowsRestoration: true,
                allowsMinimize: true,
                tabbingMode: .disallowed
            )
        case .evidenceWorkbench:
            return NativeWindowRolePolicy(
                route: route,
                allowsRestoration: false,
                allowsMinimize: true,
                tabbingMode: .disallowed
            )
        case .sourceReader:
            return NativeWindowRolePolicy(
                route: route,
                allowsRestoration: false,
                allowsMinimize: true,
                tabbingMode: .disallowed
            )
        case .settings:
            return NativeWindowRolePolicy(
                route: route,
                allowsRestoration: false,
                allowsMinimize: true,
                tabbingMode: .disallowed
            )
        case .taskCenter:
            return NativeWindowRolePolicy(
                route: route,
                allowsRestoration: false,
                allowsMinimize: true,
                tabbingMode: .disallowed
            )
        case .updatePrompt, .about, .help, .releaseNotes:
            return NativeWindowRolePolicy(
                route: route,
                allowsRestoration: false,
                allowsMinimize: false,
                tabbingMode: .disallowed
            )
        }
    }

    @MainActor
    package func apply(to window: NSWindow?) {
        guard let window else { return }
        window.tabbingMode = tabbingMode
        window.isRestorable = allowsRestoration

        if allowsMinimize {
            window.styleMask.insert(.miniaturizable)
        } else {
            window.styleMask.remove(.miniaturizable)
        }
    }
}
