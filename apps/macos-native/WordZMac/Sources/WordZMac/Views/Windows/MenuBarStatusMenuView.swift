import AppKit
import SwiftUI

struct MenuBarStatusMenuView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @Environment(\.openWindow) var openWindow
    @ObservedObject var workspace: MainWorkspaceViewModel
    @ObservedObject var sidebar: LibrarySidebarViewModel
    @ObservedObject var settings: WorkspaceSettingsViewModel
    @ObservedObject var taskCenter: NativeTaskCenter

    var body: some View {
        Group {
            workspaceSummarySection
            taskStatusSection
            Divider()
            workspaceMenuSection
            windowMenuSection
            updateMenuSection
            Divider()
            quitButton
        }
        .task {
            await workspace.initializeIfNeeded()
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    func menuLabel(_ text: String) -> String {
        WordZMenuBarTextSupport.menuLabel(text)
    }

    func prefixedMenuLabel(_ zhPrefix: String, _ enPrefix: String, value: String) -> String {
        menuLabel(t(zhPrefix, enPrefix) + value)
    }
}
