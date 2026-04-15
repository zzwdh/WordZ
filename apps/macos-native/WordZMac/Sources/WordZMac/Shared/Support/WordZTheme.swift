import AppKit
import SwiftUI

enum WordZTheme {
    static let primary = Color.accentColor
    static let action = Color.accentColor
    static let workspaceBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .underPageBackgroundColor)
    static let chromeBackground = Color(nsColor: .underPageBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let cardSecondaryBackground = Color(nsColor: .textBackgroundColor)
    static let divider = Color(nsColor: .separatorColor)
    static let shellBorder = Color(nsColor: .separatorColor).opacity(0.85)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.78)

    static let primarySurface = Color.accentColor.opacity(0.08)
    static let primarySurfaceSoft = Color.accentColor.opacity(0.05)
    static let primarySurfaceStrong = Color.accentColor.opacity(0.14)
    static let primaryStroke = Color.accentColor.opacity(0.22)

    static let sectionSpacing: CGFloat = 12
    static let pagePadding: CGFloat = 16
    static let pageScrollIndicatorGutter: CGFloat = 18
    static let radiusMedium: CGFloat = 10
    static let sidebarWidth: CGFloat = 280
    static let pageMaxWidth: CGFloat = 1440

    static func workspaceBackground(for style: WordZVisualStyle) -> Color {
        switch style.tier {
        case .baseline:
            return workspaceBackground
        case .chromeOnly:
            return Color(nsColor: .windowBackgroundColor)
        case .glassSurface:
            return Color(nsColor: .windowBackgroundColor).opacity(0.96)
        case .fullVisualRefresh:
            return Color(nsColor: .underPageBackgroundColor).opacity(0.94)
        }
    }

    static func adaptiveCardBackground(for style: WordZVisualStyle) -> Color {
        switch style.tier {
        case .baseline:
            return cardBackground
        case .chromeOnly:
            return Color(nsColor: .controlBackgroundColor).opacity(0.92)
        case .glassSurface, .fullVisualRefresh:
            return Color.white.opacity(0.12)
        }
    }

    static func surfaceStroke(for style: WordZVisualStyle) -> Color {
        switch style.tier {
        case .baseline:
            return divider.opacity(0.6)
        case .chromeOnly:
            return divider.opacity(0.45)
        case .glassSurface, .fullVisualRefresh:
            return Color.white.opacity(0.16)
        }
    }
}
