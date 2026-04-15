import AppKit
import OSLog
import SwiftUI

private let menuBarLogger = WordZTelemetry.logger(category: "MenuBar")

extension MenuBarStatusMenuView {
    @ViewBuilder
    func taskMenuItem(_ item: NativeBackgroundTaskItem) -> some View {
        let title = menuLabel("\(item.title) · \(item.progressLabel(in: languageMode))")
        if let action = item.primaryAction {
            Button(title) {
                performMenuBarAction("taskAction", detail: item.title) {
                    await workspace.performTaskAction(action)
                }
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
        logMenuBarAction("openSettings", detail: NativeWindowRoute.settings.id)
        NativeSettingsSupport.openSettingsWindow()
    }

    func windowTitle(_ route: NativeWindowRoute) -> String {
        route.title(in: languageMode)
    }

    func openWindowRoute(_ route: NativeWindowRoute) {
        logMenuBarAction("openWindow", detail: route.id)
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

    func performMenuBarAction(
        _ action: String,
        detail: String = "",
        _ operation: @escaping @MainActor () async -> Void
    ) {
        logMenuBarAction(action, detail: detail)
        Task { await operation() }
    }

    func logMenuBarAction(_ action: String, detail: String = "") {
        if detail.isEmpty {
            menuBarLogger.info("action=\(action, privacy: .public)")
        } else {
            menuBarLogger.info("action=\(action, privacy: .public) detail=\(detail, privacy: .public)")
        }
    }
}
