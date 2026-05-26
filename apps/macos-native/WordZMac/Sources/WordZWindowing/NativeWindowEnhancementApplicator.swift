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

        let scenePolicy = NativeWindowScenePolicy.policy(for: route)
        window.minSize = scenePolicy.minimumSize

        let profile = NativeWindowPresentationProfile.profile(for: route)
        let resolvedTier = profile.resolvedChromeTier(capabilities: capabilities)
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

        if capabilities.supportsAdvancedWindowPlacement,
           !capabilities.supportsWindowPlacementModifiers,
           profile.prefersAdvancedPlacement {
            applyPreferredPlacement(to: window, minimumSize: profile.minimumPlacementSize)
        }
    }

    private func applyPreferredPlacement(to window: NSWindow, minimumSize: CGSize?) {
        let windowIdentifier = ObjectIdentifier(window)
        guard Self.placedWindows.insert(windowIdentifier).inserted else { return }

        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let currentSize = window.frame.size
        let maximumSize = visibleFrame.map {
            CGSize(width: $0.width - 32, height: $0.height - 32)
        } ?? CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let targetSize = CGSize(
            width: min(max(currentSize.width, minimumSize?.width ?? currentSize.width), maximumSize.width),
            height: min(max(currentSize.height, minimumSize?.height ?? currentSize.height), maximumSize.height)
        )
        let targetOrigin: CGPoint
        if let visibleFrame {
            targetOrigin = CGPoint(
                x: visibleFrame.midX - (targetSize.width / 2),
                y: visibleFrame.midY - (targetSize.height / 2)
            )
        } else {
            targetOrigin = window.frame.origin
        }

        window.setFrame(NSRect(origin: targetOrigin, size: targetSize), display: false)
    }
}
