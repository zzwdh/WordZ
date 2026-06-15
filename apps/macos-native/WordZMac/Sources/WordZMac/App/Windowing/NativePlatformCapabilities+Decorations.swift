import CoreGraphics
import SwiftUI

import WordZWindowing
extension NativePlatformCapabilities {
    @MainActor
    static func decorateWindowRoot<Content: View>(
        _ content: Content,
        route: NativeWindowRoute,
        topInset: CGFloat
    ) -> AnyView {
        let capabilities = current
        let profile = NativeWindowPresentationProfile.profile(for: route)
        let resolvedTier = profile.resolvedChromeTier(capabilities: capabilities)
        var decorated = AnyView(content)

        if capabilities.supportsWindowContainerBackground, resolvedTier >= .glassSurface {
            if #available(macOS 26.0, *) {
                decorated = AnyView(
                    decorated.containerBackground(.regularMaterial, for: .window)
                )
            }
        }

        if capabilities.supportsWindowChromeEnhancements, profile.prefersHiddenTitle {
            if #available(macOS 26.0, *) {
                decorated = AnyView(
                    decorated.toolbar(removing: .title)
                )
            }
        }

        if capabilities.supportsWindowChromeEnhancements, profile.prefersToolbarBackgroundHidden {
            if #available(macOS 15.0, *) {
                decorated = AnyView(
                    decorated.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                )
            }
        }

        if capabilities.supportsWindowChromeEnhancements {
            if #available(macOS 15.0, *) {
                let rolePolicy = NativeWindowRolePolicy.policy(for: route)
                decorated = AnyView(
                    decorated.windowMinimizeBehavior(rolePolicy.allowsMinimize ? .enabled : .disabled)
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

        if capabilities.supportsBackgroundExtension, resolvedTier == .fullVisualRefresh {
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

        switch style.chromeTier {
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
        switch style.contentTier {
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
        switch style.chromeTier {
        case .baseline, .chromeOnly:
            return AnyView(content)
        case .glassSurface, .fullVisualRefresh:
            if current.supportsLiquidGlass {
                if #available(macOS 26.0, *) {
                    let glassContent = content
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .glassEffect(in: Capsule())
                    if current.supportsGlassButtons {
                        return AnyView(glassContent.buttonStyle(.glass))
                    }
                    return AnyView(glassContent)
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
    static func decorateIssueBannerSurface<Content: View>(
        _ content: Content,
        style: WordZVisualStyle,
        cornerRadius: CGFloat
    ) -> AnyView {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        switch style.accessoryTier {
        case .baseline, .chromeOnly:
            return AnyView(
                content
                    .background(WordZTheme.cardBackground, in: shape)
                    .overlay(shape.stroke(WordZTheme.shellBorder, lineWidth: 1))
            )
        case .glassSurface, .fullVisualRefresh:
            if current.supportsAccessoryGlassSurfaces {
                if #available(macOS 26.0, *) {
                    return AnyView(
                        content.glassEffect(.regular.interactive(), in: shape)
                    )
                }
            }
            return AnyView(
                content
                    .background(.regularMaterial, in: shape)
                    .overlay(shape.stroke(WordZTheme.surfaceStroke(for: style), lineWidth: 1))
            )
        }
    }

    @MainActor
    static func decorateFloatingAccessorySurface<Content: View>(
        _ content: Content,
        style: WordZVisualStyle
    ) -> AnyView {
        decorateAccessorySurface(
            content,
            style: style,
            cornerRadius: 18,
            isInteractive: true
        )
    }

    @MainActor
    static func decorateEmptyStateSurface<Content: View>(
        _ content: Content,
        style: WordZVisualStyle
    ) -> AnyView {
        decorateAccessorySurface(
            content,
            style: style,
            cornerRadius: 16,
            isInteractive: false
        )
    }

    @MainActor
    static func decorateSelectionAccessorySurface<Content: View>(
        _ content: Content,
        style: WordZVisualStyle
    ) -> AnyView {
        decorateAccessorySurface(
            content,
            style: style,
            cornerRadius: 14,
            isInteractive: true
        )
    }

    @MainActor
    static func decorateSheetSurface<Content: View>(
        _ content: Content,
        style: WordZVisualStyle
    ) -> AnyView {
        let styledContent = content.wordZVisualStyle(style)
        if current.supportsLiquidGlass {
            if #available(macOS 26.0, *) {
                return AnyView(
                    styledContent.presentationBackground(.regularMaterial)
                )
            }
        }
        return AnyView(
            styledContent.background(WordZTheme.workspaceBackground(for: style))
        )
    }

    @MainActor
    static func wrapGlassContainerIfNeeded<Content: View>(
        _ content: Content,
        style: WordZVisualStyle
    ) -> AnyView {
        guard (style.chromeTier >= .glassSurface || style.accessoryTier >= .glassSurface),
              current.supportsLiquidGlass else {
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

    @MainActor
    private static func decorateAccessorySurface<Content: View>(
        _ content: Content,
        style: WordZVisualStyle,
        cornerRadius: CGFloat,
        isInteractive: Bool
    ) -> AnyView {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        switch style.accessoryTier {
        case .baseline:
            return AnyView(content)
        case .chromeOnly:
            return AnyView(
                content
                    .background(.regularMaterial, in: shape)
                    .overlay(shape.stroke(WordZTheme.surfaceStroke(for: style), lineWidth: 1))
            )
        case .glassSurface, .fullVisualRefresh:
            if current.supportsAccessoryGlassSurfaces {
                if #available(macOS 26.0, *) {
                    if isInteractive {
                        return AnyView(content.glassEffect(.regular.interactive(), in: shape))
                    }
                    return AnyView(content.glassEffect(in: shape))
                }
            }
            return AnyView(
                content
                    .background(.regularMaterial, in: shape)
                    .overlay(shape.stroke(WordZTheme.surfaceStroke(for: style), lineWidth: 1))
            )
        }
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
