import AppKit
import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class NativeWindowPresentationTests: XCTestCase {
    func testNativePlatformCapabilitiesResolvedForMacOS14Baseline() {
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: false,
            isAtLeastMacOS26: false
        )

        XCTAssertFalse(capabilities.supportsWindowChromeEnhancements)
        XCTAssertFalse(capabilities.supportsLiquidGlass)
        XCTAssertFalse(capabilities.supportsAdvancedWindowPlacement)
        XCTAssertFalse(capabilities.supportsToolbarSearchEnhancements)
        XCTAssertFalse(capabilities.supportsScrollEdgeEffects)
        XCTAssertFalse(capabilities.supportsSplitViewAccessories)
        XCTAssertFalse(capabilities.supportsGlassButtons)
        XCTAssertFalse(capabilities.supportsBackgroundExtension)
        XCTAssertFalse(capabilities.supportsAccessoryGlassSurfaces)
    }

    func testNativePlatformCapabilitiesResolvedForMacOS15WithoutLiquidGlass() {
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: false
        )

        XCTAssertTrue(capabilities.supportsWindowChromeEnhancements)
        XCTAssertFalse(capabilities.supportsLiquidGlass)
        XCTAssertTrue(capabilities.supportsAdvancedWindowPlacement)
        XCTAssertFalse(capabilities.supportsToolbarSearchEnhancements)
        XCTAssertFalse(capabilities.supportsScrollEdgeEffects)
        XCTAssertFalse(capabilities.supportsSplitViewAccessories)
        XCTAssertFalse(capabilities.supportsGlassButtons)
        XCTAssertFalse(capabilities.supportsBackgroundExtension)
        XCTAssertFalse(capabilities.supportsAccessoryGlassSurfaces)
    }

    func testNativePlatformCapabilitiesResolvedForLiquidGlassRuntime() {
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: true
        )

        XCTAssertTrue(capabilities.supportsWindowChromeEnhancements)
        XCTAssertTrue(capabilities.supportsLiquidGlass)
        XCTAssertTrue(capabilities.supportsAdvancedWindowPlacement)
        XCTAssertTrue(capabilities.supportsToolbarSearchEnhancements)
        XCTAssertTrue(capabilities.supportsScrollEdgeEffects)
        XCTAssertTrue(capabilities.supportsSplitViewAccessories)
        XCTAssertTrue(capabilities.supportsGlassButtons)
        XCTAssertTrue(capabilities.supportsBackgroundExtension)
        XCTAssertTrue(capabilities.supportsAccessoryGlassSurfaces)
    }

    func testPresentationProfileFallsBackToBaselineOnMacOS14() {
        let profile = NativeWindowPresentationProfile.profile(for: .about)
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: false,
            isAtLeastMacOS26: false
        )

        XCTAssertEqual(profile.resolvedTier(capabilities: capabilities), .baseline)
    }

    func testPresentationProfileDowngradesGlassSurfaceToChromeOnlyWithoutLiquidGlass() {
        let profile = NativeWindowPresentationProfile.profile(for: .updatePrompt)
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: false
        )

        XCTAssertEqual(profile.resolvedTier(capabilities: capabilities), .chromeOnly)
    }

    func testPresentationProfileKeepsFullVisualRefreshWhenLiquidGlassIsAvailable() {
        let profile = NativeWindowPresentationProfile.profile(for: .mainWorkspace)
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: true
        )

        XCTAssertEqual(profile.resolvedTier(capabilities: capabilities), .fullVisualRefresh)
    }

    func testMainWorkspaceVisualStyleDowngradesLiquidGlassToChromeOnlyForStableResultCards() {
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: true
        )

        let style = WordZVisualStyle.resolve(for: .mainWorkspace, capabilities: capabilities)

        XCTAssertEqual(style.tier, .chromeOnly)
        XCTAssertFalse(style.usesAdaptiveToolbarSurface)
    }

    func testMainWorkspaceAccessoryStyleCanUseGlassWithoutUpgradingResultCards() {
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: true
        )

        let contentStyle = WordZVisualStyle.resolve(for: .mainWorkspace, capabilities: capabilities)
        let accessoryStyle = WordZVisualStyle.resolveAccessory(for: .mainWorkspace, capabilities: capabilities)

        XCTAssertEqual(contentStyle.tier, .chromeOnly)
        XCTAssertEqual(accessoryStyle.tier, .glassSurface)
        XCTAssertTrue(accessoryStyle.usesAdaptiveToolbarSurface)
    }

    func testMainWorkspaceAccessoryStyleFallsBackBeforeLiquidGlassRuntime() {
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: false
        )

        let accessoryStyle = WordZVisualStyle.resolveAccessory(for: .mainWorkspace, capabilities: capabilities)

        XCTAssertEqual(accessoryStyle.tier, .chromeOnly)
        XCTAssertFalse(accessoryStyle.usesAdaptiveToolbarSurface)
    }

    func testLibraryVisualStyleStillUsesFullVisualRefreshWhenLiquidGlassIsAvailable() {
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: true
        )

        let style = WordZVisualStyle.resolve(for: .library, capabilities: capabilities)

        XCTAssertEqual(style.tier, .fullVisualRefresh)
        XCTAssertTrue(style.usesAdaptiveToolbarSurface)
    }

    func testPresentationProfileRoutesToolbarSearchAndSplitAccessoryModesOnMacOS26() {
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: true
        )

        XCTAssertEqual(
            NativeWindowPresentationProfile.profile(for: .mainWorkspace)
                .resolvedToolbarMode(capabilities: capabilities),
            .swiftUIPrimary
        )
        XCTAssertEqual(
            NativeWindowPresentationProfile.profile(for: .mainWorkspace)
                .resolvedSplitAccessoryMode(capabilities: capabilities),
            .mainWorkspaceTopAccessory
        )
        XCTAssertEqual(
            NativeWindowPresentationProfile.profile(for: .library)
                .resolvedSearchMode(capabilities: capabilities),
            .libraryToolbar
        )
        XCTAssertEqual(
            NativeWindowPresentationProfile.profile(for: .taskCenter)
                .resolvedSearchMode(capabilities: capabilities),
            .taskCenterToolbar
        )
        XCTAssertEqual(
            NativeWindowPresentationProfile.profile(for: .about)
                .resolvedToolbarMode(capabilities: capabilities),
            .utilitySceneChrome
        )
    }

    func testPresentationProfileDisablesSearchAndAccessoryModesBeforeMacOS26() {
        let capabilities = NativePlatformCapabilities.resolved(
            isAtLeastMacOS15: true,
            isAtLeastMacOS26: false
        )

        XCTAssertEqual(
            NativeWindowPresentationProfile.profile(for: .library)
                .resolvedSearchMode(capabilities: capabilities),
            .none
        )
        XCTAssertEqual(
            NativeWindowPresentationProfile.profile(for: .mainWorkspace)
                .resolvedSplitAccessoryMode(capabilities: capabilities),
            .none
        )
    }

    func testScenePolicyUsesDefaultWorkspaceWindowSizes() {
        let mainPolicy = NativeWindowScenePolicy.policy(for: .mainWorkspace)
        let libraryPolicy = NativeWindowScenePolicy.policy(for: .library)
        let sourceReaderPolicy = NativeWindowScenePolicy.policy(for: .sourceReader)
        let settingsPolicy = NativeWindowScenePolicy.policy(for: .settings)

        XCTAssertEqual(mainPolicy.defaultSize, CGSize(width: 1180, height: 760))
        XCTAssertEqual(mainPolicy.resizability, .automatic)
        XCTAssertEqual(libraryPolicy.defaultSize, CGSize(width: 1120, height: 760))
        XCTAssertEqual(libraryPolicy.resizability, .automatic)
        XCTAssertEqual(sourceReaderPolicy.defaultSize, CGSize(width: 1080, height: 760))
        XCTAssertEqual(sourceReaderPolicy.resizability, .automatic)
        XCTAssertEqual(settingsPolicy.defaultSize, CGSize(width: 980, height: 720))
        XCTAssertEqual(settingsPolicy.resizability, .automatic)
    }

    func testScenePolicyKeepsUtilityWindowsContentSized() {
        let taskCenterPolicy = NativeWindowScenePolicy.policy(for: .taskCenter)
        let updatePolicy = NativeWindowScenePolicy.policy(for: .updatePrompt)
        let aboutPolicy = NativeWindowScenePolicy.policy(for: .about)

        XCTAssertEqual(taskCenterPolicy.defaultSize, CGSize(width: 560, height: 420))
        XCTAssertEqual(taskCenterPolicy.resizability, .contentSize)
        XCTAssertEqual(updatePolicy.defaultSize, CGSize(width: 560, height: 420))
        XCTAssertEqual(updatePolicy.resizability, .contentSize)
        XCTAssertEqual(aboutPolicy.defaultSize, CGSize(width: 460, height: 360))
        XCTAssertEqual(aboutPolicy.resizability, .contentSize)
    }

    func testWindowChromeConfiguratorResetsBaselineWindowChrome() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.toolbarStyle = .unifiedCompact

        NativeWindowChromeConfigurator().apply(to: window, route: .mainWorkspace)

        XCTAssertFalse(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertFalse(window.isMovableByWindowBackground)
        XCTAssertEqual(window.toolbarStyle, .automatic)
    }

    func testWindowEnhancementApplicatorLeavesMacOS14BaselineUntouched() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let applicator = NativeWindowEnhancementApplicator(
            capabilities: NativePlatformCapabilities.resolved(
                isAtLeastMacOS15: false,
                isAtLeastMacOS26: false
            )
        )

        applicator.apply(to: window, route: .about)

        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertFalse(window.isMovableByWindowBackground)
    }

    func testWindowEnhancementApplicatorAppliesUtilityWindowChromeOnSupportedRuntime() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let applicator = NativeWindowEnhancementApplicator(
            capabilities: NativePlatformCapabilities.resolved(
                isAtLeastMacOS15: true,
                isAtLeastMacOS26: false
            )
        )

        applicator.apply(to: window, route: .about)

        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.isMovableByWindowBackground)
        XCTAssertEqual(window.toolbarStyle, .unifiedCompact)
        XCTAssertGreaterThanOrEqual(window.frame.width, 460)
        XCTAssertGreaterThanOrEqual(window.frame.height, 360)
    }
}
