import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
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
        content.background(
            WindowAccessor { window in
                NativeWindowRouting.register(window, for: route)
                NativeWindowRolePolicy.policy(for: route).apply(to: window)
                chromeConfigurator.apply(to: window, route: route)
                if let titleProvider {
                    window?.title = titleProvider(languageMode)
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
