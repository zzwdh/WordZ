import CoreGraphics
import Foundation

package enum WindowEnhancementTier: Int, CaseIterable, Comparable {
    case baseline
    case chromeOnly
    case glassSurface
    case fullVisualRefresh

    package static func < (lhs: WindowEnhancementTier, rhs: WindowEnhancementTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package enum NativeWindowToolbarMode: Equatable {
    case none
    case swiftUIPrimary
    case utilitySceneChrome
}

package enum NativeWindowSearchMode: Equatable {
    case none
    case libraryToolbar
    case taskCenterToolbar
}

package enum NativeWindowSplitAccessoryMode: Equatable {
    case none
    case mainWorkspaceTopAccessory
}

package struct NativeWindowVisualTiers: Equatable, Sendable {
    package let chrome: WindowEnhancementTier
    package let content: WindowEnhancementTier
    package let accessory: WindowEnhancementTier

    package init(
        chrome: WindowEnhancementTier,
        content: WindowEnhancementTier,
        accessory: WindowEnhancementTier
    ) {
        self.chrome = chrome
        self.content = content
        self.accessory = accessory
    }

    package static let baseline = NativeWindowVisualTiers(
        chrome: .baseline,
        content: .baseline,
        accessory: .baseline
    )
}

package struct NativeWindowPresentationProfile: Equatable {
    package let route: NativeWindowRoute
    package let visualTiers: NativeWindowVisualTiers
    package let toolbarMode: NativeWindowToolbarMode
    package let searchMode: NativeWindowSearchMode
    package let splitAccessoryMode: NativeWindowSplitAccessoryMode
    package let prefersTransparentTitleBar: Bool
    package let prefersHiddenTitle: Bool
    package let prefersBackgroundDrag: Bool
    package let prefersToolbarBackgroundHidden: Bool
    package let prefersAdvancedPlacement: Bool
    package let minimumPlacementSize: CGSize?

    package var preferredTier: WindowEnhancementTier {
        max(visualTiers.chrome, visualTiers.content, visualTiers.accessory)
    }

    package static func profile(for route: NativeWindowRoute) -> NativeWindowPresentationProfile {
        switch route {
        case .mainWorkspace:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .fullVisualRefresh,
                    content: .chromeOnly,
                    accessory: .glassSurface
                ),
                toolbarMode: .swiftUIPrimary,
                searchMode: .none,
                splitAccessoryMode: .mainWorkspaceTopAccessory,
                prefersTransparentTitleBar: false,
                prefersHiddenTitle: false,
                prefersBackgroundDrag: false,
                prefersToolbarBackgroundHidden: false,
                prefersAdvancedPlacement: false,
                minimumPlacementSize: nil
            )
        case .library:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .fullVisualRefresh,
                    content: .chromeOnly,
                    accessory: .glassSurface
                ),
                toolbarMode: .swiftUIPrimary,
                searchMode: .libraryToolbar,
                splitAccessoryMode: .none,
                prefersTransparentTitleBar: true,
                prefersHiddenTitle: true,
                prefersBackgroundDrag: true,
                prefersToolbarBackgroundHidden: true,
                prefersAdvancedPlacement: false,
                minimumPlacementSize: nil
            )
        case .evidenceWorkbench:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .fullVisualRefresh,
                    content: .chromeOnly,
                    accessory: .glassSurface
                ),
                toolbarMode: .swiftUIPrimary,
                searchMode: .none,
                splitAccessoryMode: .none,
                prefersTransparentTitleBar: false,
                prefersHiddenTitle: false,
                prefersBackgroundDrag: false,
                prefersToolbarBackgroundHidden: false,
                prefersAdvancedPlacement: false,
                minimumPlacementSize: nil
            )
        case .sourceReader:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .fullVisualRefresh,
                    content: .chromeOnly,
                    accessory: .glassSurface
                ),
                toolbarMode: .swiftUIPrimary,
                searchMode: .none,
                splitAccessoryMode: .none,
                prefersTransparentTitleBar: false,
                prefersHiddenTitle: false,
                prefersBackgroundDrag: false,
                prefersToolbarBackgroundHidden: false,
                prefersAdvancedPlacement: false,
                minimumPlacementSize: nil
            )
        case .settings:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .fullVisualRefresh,
                    content: .fullVisualRefresh,
                    accessory: .glassSurface
                ),
                toolbarMode: .swiftUIPrimary,
                searchMode: .none,
                splitAccessoryMode: .none,
                prefersTransparentTitleBar: false,
                prefersHiddenTitle: false,
                prefersBackgroundDrag: false,
                prefersToolbarBackgroundHidden: false,
                prefersAdvancedPlacement: false,
                minimumPlacementSize: nil
            )
        case .taskCenter:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .glassSurface,
                    content: .glassSurface,
                    accessory: .glassSurface
                ),
                toolbarMode: .utilitySceneChrome,
                searchMode: .taskCenterToolbar,
                splitAccessoryMode: .none,
                prefersTransparentTitleBar: true,
                prefersHiddenTitle: true,
                prefersBackgroundDrag: true,
                prefersToolbarBackgroundHidden: true,
                prefersAdvancedPlacement: true,
                minimumPlacementSize: CGSize(width: 560, height: 420)
            )
        case .updatePrompt:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .glassSurface,
                    content: .glassSurface,
                    accessory: .glassSurface
                ),
                toolbarMode: .utilitySceneChrome,
                searchMode: .none,
                splitAccessoryMode: .none,
                prefersTransparentTitleBar: true,
                prefersHiddenTitle: true,
                prefersBackgroundDrag: true,
                prefersToolbarBackgroundHidden: true,
                prefersAdvancedPlacement: true,
                minimumPlacementSize: CGSize(width: 560, height: 420)
            )
        case .about:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .glassSurface,
                    content: .glassSurface,
                    accessory: .glassSurface
                ),
                toolbarMode: .utilitySceneChrome,
                searchMode: .none,
                splitAccessoryMode: .none,
                prefersTransparentTitleBar: true,
                prefersHiddenTitle: true,
                prefersBackgroundDrag: true,
                prefersToolbarBackgroundHidden: true,
                prefersAdvancedPlacement: true,
                minimumPlacementSize: CGSize(width: 460, height: 360)
            )
        case .help:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .glassSurface,
                    content: .glassSurface,
                    accessory: .glassSurface
                ),
                toolbarMode: .utilitySceneChrome,
                searchMode: .none,
                splitAccessoryMode: .none,
                prefersTransparentTitleBar: true,
                prefersHiddenTitle: true,
                prefersBackgroundDrag: true,
                prefersToolbarBackgroundHidden: true,
                prefersAdvancedPlacement: true,
                minimumPlacementSize: CGSize(width: 520, height: 420)
            )
        case .releaseNotes:
            return NativeWindowPresentationProfile(
                route: route,
                visualTiers: NativeWindowVisualTiers(
                    chrome: .glassSurface,
                    content: .glassSurface,
                    accessory: .glassSurface
                ),
                toolbarMode: .utilitySceneChrome,
                searchMode: .none,
                splitAccessoryMode: .none,
                prefersTransparentTitleBar: true,
                prefersHiddenTitle: true,
                prefersBackgroundDrag: true,
                prefersToolbarBackgroundHidden: true,
                prefersAdvancedPlacement: true,
                minimumPlacementSize: CGSize(width: 560, height: 420)
            )
        }
    }

    package func resolvedTier(capabilities: NativePlatformCapabilities) -> WindowEnhancementTier {
        max(
            resolvedChromeTier(capabilities: capabilities),
            resolvedContentTier(capabilities: capabilities),
            resolvedAccessoryTier(capabilities: capabilities)
        )
    }

    package func resolvedChromeTier(capabilities: NativePlatformCapabilities) -> WindowEnhancementTier {
        resolvedTier(visualTiers.chrome, capabilities: capabilities)
    }

    package func resolvedContentTier(capabilities: NativePlatformCapabilities) -> WindowEnhancementTier {
        resolvedTier(visualTiers.content, capabilities: capabilities)
    }

    package func resolvedAccessoryTier(capabilities: NativePlatformCapabilities) -> WindowEnhancementTier {
        resolvedTier(visualTiers.accessory, capabilities: capabilities)
    }

    private func resolvedTier(
        _ tier: WindowEnhancementTier,
        capabilities: NativePlatformCapabilities
    ) -> WindowEnhancementTier {
        guard capabilities.supportsWindowChromeEnhancements else {
            return .baseline
        }

        switch tier {
        case .baseline:
            return .baseline
        case .chromeOnly:
            return .chromeOnly
        case .glassSurface:
            return capabilities.supportsLiquidGlass ? .glassSurface : .chromeOnly
        case .fullVisualRefresh:
            return capabilities.supportsLiquidGlass ? .fullVisualRefresh : .chromeOnly
        }
    }

    package func resolvedToolbarMode(capabilities: NativePlatformCapabilities) -> NativeWindowToolbarMode {
        switch toolbarMode {
        case .none:
            return .none
        case .swiftUIPrimary:
            return .swiftUIPrimary
        case .utilitySceneChrome:
            return capabilities.supportsWindowChromeEnhancements ? .utilitySceneChrome : .none
        }
    }

    package func resolvedSearchMode(capabilities: NativePlatformCapabilities) -> NativeWindowSearchMode {
        guard capabilities.supportsSearchToolbarBehavior else {
            return .none
        }
        return searchMode
    }

    package func resolvedSplitAccessoryMode(capabilities: NativePlatformCapabilities) -> NativeWindowSplitAccessoryMode {
        guard capabilities.supportsSplitViewAccessories else {
            return .none
        }
        return splitAccessoryMode
    }
}
