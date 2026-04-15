import SwiftUI

struct AdaptiveWindowScaffold<Content: View>: View {
    let route: NativeWindowRoute
    let content: Content

    @State private var safeAreaTopInset: CGFloat = 0
    private let insetUpdateTolerance: CGFloat = 0.5

    init(
        route: NativeWindowRoute,
        @ViewBuilder content: () -> Content
    ) {
        self.route = route
        self.content = content()
    }

    private var visualStyle: WordZVisualStyle {
        WordZVisualStyle.resolve(for: route)
    }

    var body: some View {
        let baseContent = content
            .wordZVisualStyle(visualStyle)
            .background(
                WindowSafeAreaTopInsetReader { resolvedInset in
                    guard abs(safeAreaTopInset - resolvedInset) > insetUpdateTolerance else {
                        return
                    }
                    safeAreaTopInset = resolvedInset
                }
            )

        NativePlatformCapabilities.decorateWindowRoot(
            NativePlatformCapabilities.wrapGlassContainerIfNeeded(baseContent, style: visualStyle),
            route: route,
            topInset: safeAreaTopInset
        )
    }
}

struct AdaptiveHeaderSurface<Content: View>: View {
    @Environment(\.wordZVisualStyle) private var visualStyle

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NativePlatformCapabilities.decorateHeaderSurface(content, style: visualStyle)
    }
}

struct AdaptiveInspectorSurface<Content: View>: View {
    @Environment(\.wordZVisualStyle) private var visualStyle

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NativePlatformCapabilities.decorateInspectorSurface(content, style: visualStyle)
    }
}

struct AdaptiveToolbarSurface<Content: View>: View {
    @Environment(\.wordZVisualStyle) private var visualStyle

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NativePlatformCapabilities.decorateToolbarSurface(content, style: visualStyle)
    }
}

extension View {
    func adaptiveWindowScaffold(for route: NativeWindowRoute) -> some View {
        AdaptiveWindowScaffold(route: route) {
            self
        }
    }
}
