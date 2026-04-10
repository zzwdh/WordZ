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

    static let sectionSpacing: CGFloat = 12
    static let pagePadding: CGFloat = 16
    static let radiusMedium: CGFloat = 10
    static let sidebarWidth: CGFloat = 280
    static let pageMaxWidth: CGFloat = 1440
}
