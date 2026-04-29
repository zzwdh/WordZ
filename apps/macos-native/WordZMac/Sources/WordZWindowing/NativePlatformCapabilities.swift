import Foundation

package struct NativePlatformCapabilities: Equatable, Sendable {
    package let supportsWindowChromeEnhancements: Bool
    package let supportsLiquidGlass: Bool
    package let supportsAdvancedWindowPlacement: Bool
    package let supportsToolbarSearchEnhancements: Bool
    package let supportsScrollEdgeEffects: Bool
    package let supportsSplitViewAccessories: Bool
    package let supportsGlassButtons: Bool
    package let supportsBackgroundExtension: Bool
    package let supportsAccessoryGlassSurfaces: Bool

    package static var current: NativePlatformCapabilities {
        resolved(
            isAtLeastMacOS15: {
                if #available(macOS 15.0, *) {
                    return true
                }
                return false
            }(),
            isAtLeastMacOS26: {
                if #available(macOS 26.0, *) {
                    return true
                }
                return false
            }()
        )
    }

    package static func resolved(
        isAtLeastMacOS15: Bool,
        isAtLeastMacOS26: Bool
    ) -> NativePlatformCapabilities {
        NativePlatformCapabilities(
            supportsWindowChromeEnhancements: isAtLeastMacOS15,
            supportsLiquidGlass: isAtLeastMacOS26,
            supportsAdvancedWindowPlacement: isAtLeastMacOS15,
            supportsToolbarSearchEnhancements: isAtLeastMacOS26,
            supportsScrollEdgeEffects: isAtLeastMacOS26,
            supportsSplitViewAccessories: isAtLeastMacOS26,
            supportsGlassButtons: isAtLeastMacOS26,
            supportsBackgroundExtension: isAtLeastMacOS26,
            supportsAccessoryGlassSurfaces: isAtLeastMacOS26
        )
    }
}
