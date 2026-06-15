import AppKit
import SwiftUI

import WordZWindowing
import WordZShared
struct WindowAccessor: NSViewRepresentable {
    struct ResolutionKey: Equatable {
        let routeID: String?
        let title: String?
    }

    let resolutionKey: ResolutionKey
    let onResolve: (NSWindow?, NSWindow?) -> Void

    init(
        resolutionKey: ResolutionKey = ResolutionKey(routeID: nil, title: nil),
        onResolve: @escaping (NSWindow?, NSWindow?) -> Void
    ) {
        self.resolutionKey = resolutionKey
        self.onResolve = onResolve
    }

    final class Coordinator {
        weak var lastResolvedWindow: NSWindow?
        weak var pendingResolvedWindow: NSWindow?
        var lastResolutionKey: ResolutionKey?
        var pendingResolutionKey: ResolutionKey?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        scheduleResolve(for: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        scheduleResolve(for: nsView, coordinator: context.coordinator)
    }

    private func scheduleResolve(for view: NSView, coordinator: Coordinator) {
        let window = view.window
        if coordinator.lastResolvedWindow === window,
           coordinator.lastResolutionKey == resolutionKey {
            return
        }
        if coordinator.pendingResolvedWindow === window,
           coordinator.pendingResolutionKey == resolutionKey {
            return
        }

        coordinator.pendingResolvedWindow = window
        coordinator.pendingResolutionKey = resolutionKey
        DispatchQueue.main.async {
            let resolvedWindow = view.window
            let previousWindow = coordinator.lastResolvedWindow
            if coordinator.lastResolvedWindow === resolvedWindow,
               coordinator.lastResolutionKey == resolutionKey {
                coordinator.pendingResolvedWindow = nil
                coordinator.pendingResolutionKey = nil
                return
            }
            guard resolvedWindow != nil || previousWindow != nil else {
                coordinator.pendingResolvedWindow = nil
                coordinator.pendingResolutionKey = nil
                return
            }
            coordinator.lastResolvedWindow = resolvedWindow
            coordinator.lastResolutionKey = resolutionKey
            coordinator.pendingResolvedWindow = nil
            coordinator.pendingResolutionKey = nil
            onResolve(resolvedWindow, previousWindow)
        }
    }
}

struct WindowSafeAreaTopInsetReader: NSViewRepresentable {
    let onResolve: (CGFloat) -> Void

    final class Coordinator {
        var lastResolvedInset: CGFloat?
        var pendingResolvedInset: CGFloat?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        scheduleResolve(for: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        scheduleResolve(for: nsView, coordinator: context.coordinator)
    }

    private func resolvedInset(for view: NSView) -> CGFloat {
        let safeAreaTop = max(0, view.safeAreaInsets.top)
        return safeAreaTop > 1 ? safeAreaTop : 0
    }

    private func scheduleResolve(for view: NSView, coordinator: Coordinator) {
        let resolvedInset = resolvedInset(for: view)
        if let pendingResolvedInset = coordinator.pendingResolvedInset,
           abs(pendingResolvedInset - resolvedInset) <= 0.5 {
            return
        }
        if let lastResolvedInset = coordinator.lastResolvedInset,
           abs(lastResolvedInset - resolvedInset) <= 0.5 {
            return
        }

        coordinator.pendingResolvedInset = resolvedInset
        DispatchQueue.main.async {
            coordinator.lastResolvedInset = resolvedInset
            coordinator.pendingResolvedInset = nil
            onResolve(resolvedInset)
        }
    }
}

struct WindowRouteBinder: ViewModifier {
    @Environment(\.wordZLanguageMode) private var languageMode

    let route: NativeWindowRoute
    let titleProvider: ((AppLanguageMode) -> String)?
    let onResolve: (NSWindow?) -> Void

    private let chromeConfigurator = NativeWindowChromeConfigurator()
    private let enhancementApplicator = NativeWindowEnhancementApplicator()

    func body(content: Content) -> some View {
        let resolvedTitle = titleProvider?(languageMode)
        content.background(
            WindowAccessor(
                resolutionKey: WindowAccessor.ResolutionKey(
                    routeID: route.id,
                    title: resolvedTitle
                )
            ) { window, previousWindow in
                if previousWindow !== window {
                    NativeWindowRouting.unregister(previousWindow, for: route)
                }
                guard let window else {
                    onResolve(nil)
                    return
                }
                NativeWindowRouting.register(window, for: route)
                NativeWindowRolePolicy.policy(for: route).apply(to: window)
                chromeConfigurator.apply(to: window, route: route)
                if let resolvedTitle {
                    window.title = resolvedTitle
                }
                enhancementApplicator.apply(to: window, route: route)
                onResolve(window)
            }
        )
    }
}

extension View {
    func bindWindowRoute(
        _ route: NativeWindowRoute,
        titleProvider: ((AppLanguageMode) -> String)? = nil,
        onResolve: @escaping (NSWindow?) -> Void = { _ in }
    ) -> some View {
        modifier(WindowRouteBinder(route: route, titleProvider: titleProvider, onResolve: onResolve))
    }
}
