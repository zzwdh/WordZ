import SwiftUI

import WordZWindowing
struct WordZVisualStyle: Equatable {
    let route: NativeWindowRoute
    let chromeTier: WindowEnhancementTier
    let contentTier: WindowEnhancementTier
    let accessoryTier: WindowEnhancementTier

    static let baseline = WordZVisualStyle(
        route: .mainWorkspace,
        chromeTier: .baseline,
        contentTier: .baseline,
        accessoryTier: .baseline
    )

    var tier: WindowEnhancementTier {
        contentTier
    }

    var usesAdaptiveHeaderSurface: Bool {
        chromeTier != .baseline
    }

    var usesAdaptiveSectionSurface: Bool {
        contentTier != .baseline
    }

    var usesAdaptiveToolbarSurface: Bool {
        chromeTier >= .glassSurface
    }

    var headerHorizontalPadding: CGFloat {
        chromeTier == .baseline ? 0 : 14
    }

    var headerVerticalPadding: CGFloat {
        chromeTier == .baseline ? 0 : 12
    }

    var sectionInnerPadding: CGFloat {
        12
    }

    static func resolve(
        for route: NativeWindowRoute,
        capabilities: NativePlatformCapabilities = .current
    ) -> WordZVisualStyle {
        let profile = NativeWindowPresentationProfile.profile(for: route)
        return WordZVisualStyle(
            route: route,
            chromeTier: profile.resolvedChromeTier(capabilities: capabilities),
            contentTier: profile.resolvedContentTier(capabilities: capabilities),
            accessoryTier: profile.resolvedAccessoryTier(capabilities: capabilities)
        )
    }

    static func resolveAccessory(
        for route: NativeWindowRoute,
        capabilities: NativePlatformCapabilities = .current
    ) -> WordZVisualStyle {
        guard route == .mainWorkspace,
              capabilities.supportsAccessoryGlassSurfaces,
              NativeWindowPresentationProfile.profile(for: route)
                .resolvedSplitAccessoryMode(capabilities: capabilities) == .mainWorkspaceTopAccessory else {
            return resolve(for: route, capabilities: capabilities)
        }

        let profile = NativeWindowPresentationProfile.profile(for: route)
        let resolvedAccessoryTier = profile.resolvedAccessoryTier(capabilities: capabilities)
        return WordZVisualStyle(
            route: route,
            chromeTier: resolvedAccessoryTier,
            contentTier: resolvedAccessoryTier,
            accessoryTier: resolvedAccessoryTier
        )
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
