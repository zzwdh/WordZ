import SwiftUI

struct WordZVisualStyle: Equatable {
    let route: NativeWindowRoute
    let tier: WindowEnhancementTier

    static let baseline = WordZVisualStyle(route: .mainWorkspace, tier: .baseline)

    var usesAdaptiveHeaderSurface: Bool {
        tier != .baseline
    }

    var usesAdaptiveSectionSurface: Bool {
        tier != .baseline
    }

    var usesAdaptiveToolbarSurface: Bool {
        tier >= .glassSurface
    }

    var headerHorizontalPadding: CGFloat {
        tier == .baseline ? 0 : 14
    }

    var headerVerticalPadding: CGFloat {
        tier == .baseline ? 0 : 12
    }

    var sectionInnerPadding: CGFloat {
        12
    }

    static func resolve(
        for route: NativeWindowRoute,
        capabilities: NativePlatformCapabilities = .current
    ) -> WordZVisualStyle {
        let profile = NativeWindowPresentationProfile.profile(for: route)
        let resolvedTier = profile.resolvedTier(capabilities: capabilities)
        let stableTier: WindowEnhancementTier

        if route == .mainWorkspace, resolvedTier == .fullVisualRefresh {
            // The analysis workspace still shows unstable card stacking when the
            // result area uses Liquid Glass surfaces inside long scrolling panes.
            // Keep the main window on the macOS 15 chrome path until that
            // section layout is fully hardened for 26-specific materials.
            stableTier = .chromeOnly
        } else {
            stableTier = resolvedTier
        }

        return WordZVisualStyle(route: route, tier: stableTier)
    }

    static func resolveAccessory(
        for route: NativeWindowRoute,
        capabilities: NativePlatformCapabilities = .current
    ) -> WordZVisualStyle {
        let baseStyle = resolve(for: route, capabilities: capabilities)
        guard route == .mainWorkspace,
              capabilities.supportsAccessoryGlassSurfaces,
              NativeWindowPresentationProfile.profile(for: route)
                .resolvedSplitAccessoryMode(capabilities: capabilities) == .mainWorkspaceTopAccessory else {
            return baseStyle
        }

        return WordZVisualStyle(route: route, tier: .glassSurface)
    }
}

private struct WordZVisualStyleKey: EnvironmentKey {
    static let defaultValue = WordZVisualStyle.baseline
}

extension EnvironmentValues {
    var wordZVisualStyle: WordZVisualStyle {
        get { self[WordZVisualStyleKey.self] }
        set { self[WordZVisualStyleKey.self] = newValue }
    }
}

extension View {
    func wordZVisualStyle(_ style: WordZVisualStyle) -> some View {
        environment(\.wordZVisualStyle, style)
    }
}
