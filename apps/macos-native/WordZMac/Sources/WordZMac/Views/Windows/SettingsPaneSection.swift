import SwiftUI

enum SettingsSection: CaseIterable, Identifiable {
    case workspace
    case appearance
    case updates
    case recent
    case support
    case about

    var id: String {
        switch self {
        case .workspace:
            return "workspace"
        case .appearance:
            return "appearance"
        case .updates:
            return "updates"
        case .recent:
            return "recent"
        case .support:
            return "support"
        case .about:
            return "about"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .workspace:
            return wordZText("工作区", "Workspace", mode: mode)
        case .appearance:
            return wordZText("外观", "Appearance", mode: mode)
        case .updates:
            return wordZText("更新", "Updates", mode: mode)
        case .recent:
            return wordZText("最近打开", "Recent", mode: mode)
        case .support:
            return wordZText("支持", "Support", mode: mode)
        case .about:
            return wordZText("关于", "About", mode: mode)
        }
    }

    var symbolName: String {
        switch self {
        case .workspace:
            return "square.grid.2x2"
        case .appearance:
            return "paintbrush"
        case .updates:
            return "arrow.triangle.2.circlepath"
        case .recent:
            return "clock.arrow.circlepath"
        case .support:
            return "lifepreserver"
        case .about:
            return "info.circle"
        }
    }
}
