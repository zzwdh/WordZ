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

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            onResolve(resolvedInset(for: view))
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(resolvedInset(for: nsView))
        }
    }

    private func resolvedInset(for view: NSView) -> CGFloat {
        let safeAreaTop = max(0, view.safeAreaInsets.top)
        return safeAreaTop > 1 ? safeAreaTop : 0
    }
}

struct WindowRouteBinder: ViewModifier {
    let route: NativeWindowRoute
    let onResolve: (NSWindow?) -> Void

    func body(content: Content) -> some View {
        content.background(
            WindowAccessor { window in
                NativeWindowRouting.register(window, for: route)
                onResolve(window)
            }
        )
    }
}

extension View {
    func bindWindowRoute(
        _ route: NativeWindowRoute,
        onResolve: @escaping (NSWindow?) -> Void = { _ in }
    ) -> some View {
        modifier(WindowRouteBinder(route: route, onResolve: onResolve))
    }
}
