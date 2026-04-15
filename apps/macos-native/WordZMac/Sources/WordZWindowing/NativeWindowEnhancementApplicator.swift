import AppKit
import Foundation

@MainActor
package struct NativeWindowEnhancementApplicator {
    private static var placedWindows = Set<ObjectIdentifier>()

    let capabilities: NativePlatformCapabilities

    package init(capabilities: NativePlatformCapabilities = .current) {
        self.capabilities = capabilities
    }

    package func apply(to window: NSWindow?, route: NativeWindowRoute) {
        guard let window else { return }

        let profile = NativeWindowPresentationProfile.profile(for: route)
        let resolvedTier = profile.resolvedTier(capabilities: capabilities)
        guard resolvedTier != .baseline else { return }

        if profile.prefersTransparentTitleBar {
            window.titlebarAppearsTransparent = true
        }

        if profile.prefersHiddenTitle {
            window.titleVisibility = .hidden
        }

        if profile.prefersBackgroundDrag {
            window.isMovableByWindowBackground = true
        }

        if resolvedTier >= .chromeOnly {
            window.toolbarStyle = profile.prefersHiddenTitle ? .unifiedCompact : .unified
        }

        if capabilities.supportsAdvancedWindowPlacement, profile.prefersAdvancedPlacement {
            applyPreferredPlacement(to: window, minimumSize: profile.minimumPlacementSize)
        }
    }

    private func applyPreferredPlacement(to window: NSWindow, minimumSize: CGSize?) {
        let windowIdentifier = ObjectIdentifier(window)
        guard Self.placedWindows.insert(windowIdentifier).inserted else { return }
        guard let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }

        let currentSize = window.frame.size
        let targetSize = CGSize(
            width: min(max(currentSize.width, minimumSize?.width ?? currentSize.width), visibleFrame.width - 32),
            height: min(max(currentSize.height, minimumSize?.height ?? currentSize.height), visibleFrame.height - 32)
        )
        let targetOrigin = CGPoint(
            x: visibleFrame.midX - (targetSize.width / 2),
            y: visibleFrame.midY - (targetSize.height / 2)
        )

        window.setFrame(NSRect(origin: targetOrigin, size: targetSize), display: false)
    }
}
