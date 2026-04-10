import AppKit
import SwiftUI

extension MenuBarStatusMenuView {
    @ViewBuilder
    func taskMenuItem(_ item: NativeBackgroundTaskItem) -> some View {
        let title = "\(item.title) · \(item.progressLabel(in: languageMode))"
        if let action = item.primaryAction {
            Button(title) {
                Task { await workspace.performTaskAction(action) }
            }
        } else {
            Text(title)
        }
    }

    func openMainWorkspace() {
        openWindowRoute(.mainWorkspace)
    }

    func windowMenuButton(_ route: NativeWindowRoute) -> some View {
        Button(windowTitle(route)) {
            openWindowRoute(route)
        }
    }

    func openSettingsWindow() {
        NativeSettingsSupport.openSettingsWindow()
    }

    func windowTitle(_ route: NativeWindowRoute) -> String {
        route.title(in: languageMode)
    }

    func openWindowRoute(_ route: NativeWindowRoute) {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        application.activate(ignoringOtherApps: true)
        if let window = NativeWindowRouting.window(for: route) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        openWindow(id: route.id)
    }

    func openWindowRouteAndAwaitActivation(_ route: NativeWindowRoute) async {
        openWindowRoute(route)
        _ = await NativeWindowRouting.waitUntilActive(route)
    }
}
