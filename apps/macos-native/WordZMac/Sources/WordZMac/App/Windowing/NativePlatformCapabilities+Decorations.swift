import CoreGraphics
import SwiftUI

extension NativePlatformCapabilities {
    @MainActor
    static func decorateWindowRoot<Content: View>(
        _ content: Content,
        route: NativeWindowRoute,
        topInset: CGFloat
    ) -> AnyView {
        let capabilities = current
        let profile = NativeWindowPresentationProfile.profile(for: route)
        let resolvedTier = profile.resolvedTier(capabilities: capabilities)
        var decorated = AnyView(content)

        if capabilities.supportsWindowChromeEnhancements, profile.prefersToolbarBackgroundHidden {
            if #available(macOS 15.0, *) {
                decorated = AnyView(
                    decorated.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                )
            }
        }

        if capabilities.supportsWindowChromeEnhancements, profile.prefersBackgroundDrag, topInset > 0 {
            decorated = AnyView(
                decorated.overlay(alignment: .top) {
                    dragHandleOverlay(height: topInset)
                }
            )
        }

        if capabilities.supportsScrollEdgeEffects, resolvedTier >= .glassSurface {
            if #available(macOS 26.0, *) {
                decorated = AnyView(
                    decorated.scrollEdgeEffectStyle(.soft, for: .top)
                )
            }
        }

        if capabilities.supportsLiquidGlass, resolvedTier == .fullVisualRefresh {
            if #available(macOS 26.0, *) {
                decorated = AnyView(
                    decorated.backgroundExtensionEffect()
                )
            }
        }

        return decorated
    }

    @MainActor
    static func decorateHeaderSurface<Content: View>(
        _ content: Content,
        style: WordZVisualStyle
    ) -> AnyView {
        let paddedContent = AnyView(
            content
                .padding(.horizontal, style.headerHorizontalPadding)
                .padding(.vertical, style.headerVerticalPadding)
        )

        switch style.tier {
        case .baseline:
            return AnyView(content)
        case .chromeOnly:
            return AnyView(
                paddedContent.background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.regularMaterial)
                )
            )
        case .glassSurface, .fullVisualRefresh:
            if current.supportsLiquidGlass {
                if #available(macOS 26.0, *) {
                    return AnyView(
                        paddedContent.glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    )
                }
            }
            return AnyView(
                paddedContent.background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.regularMaterial)
                )
            )
        }
    }

    @MainActor
    static func decorateInspectorSurface<Content: View>(
        _ content: Content,
        style: WordZVisualStyle
    ) -> AnyView {
        switch style.tier {
        case .baseline:
            return AnyView(content)
        case .chromeOnly:
            return AnyView(
                content
                    .padding(style.sectionInnerPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.thinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(WordZTheme.surfaceStroke(for: style), lineWidth: 1)
                    )
            )
        case .glassSurface, .fullVisualRefresh:
            if current.supportsLiquidGlass {
                if #available(macOS 26.0, *) {
                    return AnyView(
                        content
                            .padding(style.sectionInnerPadding)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                }
            }
            return AnyView(
                content
                    .padding(style.sectionInnerPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(WordZTheme.surfaceStroke(for: style), lineWidth: 1)
                    )
            )
        }
    }

    @MainActor
    static func decorateToolbarSurface<Content: View>(
        _ content: Content,
        style: WordZVisualStyle
    ) -> AnyView {
        switch style.tier {
        case .baseline, .chromeOnly:
            return AnyView(content)
        case .glassSurface, .fullVisualRefresh:
            if current.supportsLiquidGlass {
                if #available(macOS 26.0, *) {
                    return AnyView(
                        content
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .glassEffect(in: Capsule())
                    )
                }
            }
            return AnyView(
                content
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
            )
        }
    }

    @MainActor
    static func wrapGlassContainerIfNeeded<Content: View>(
        _ content: Content,
        style: WordZVisualStyle
    ) -> AnyView {
        guard style.tier >= .glassSurface, current.supportsLiquidGlass else {
            return AnyView(content)
        }

        if #available(macOS 26.0, *) {
            return AnyView(
                GlassEffectContainer(spacing: 12) {
                    content
                }
            )
        }

        return AnyView(content)
    }

    @ViewBuilder
    private static func dragHandleOverlay(height: CGFloat) -> some View {
        if #available(macOS 15.0, *) {
            Color.clear
                .frame(height: height)
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
        } else {
            EmptyView()
        }
    }
}
