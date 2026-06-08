import AppKit
import OSLog
import SwiftUI

private let menuBarLogger = WordZTelemetry.logger(category: "MenuBar")

extension MenuBarStatusMenuView {
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
        guard NativeWindowRouting.shouldRequestPresentation(for: route) else { return }
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
