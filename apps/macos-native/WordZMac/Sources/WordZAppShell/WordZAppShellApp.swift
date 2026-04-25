import SwiftUI
import WordZWorkspaceCore
import WordZWorkspaceFeature

package struct WordZAppShell: App {
    @NSApplicationDelegateAdaptor(NativeApplicationDelegate.self) private var applicationDelegate
    @StateObject private var workspace: MainWorkspaceViewModel
    @StateObject private var menuBarController: WordZMenuBarController
    @StateObject private var localization = WordZLocalization.shared

    package init() {
        _ = WordZWorkspaceFeatureModule.activationSummary
        let container = NativeAppContainer.live(
            makeFeaturePages: WordZWorkspaceFeaturePageFactory.makePageBundle
        )
        let workspace = container.makeMainWorkspaceViewModel()
        _workspace = StateObject(wrappedValue: workspace)
        _menuBarController = StateObject(
            wrappedValue: WordZMenuBarController(
                workspace: workspace,
                localization: WordZLocalization.shared
            )
        )
    }

    package var body: some Scene {
        WordZCoreAppScenes.make(
            workspace: workspace,
            applicationDelegate: applicationDelegate,
            menuBarController: menuBarController,
            localization: localization
        )
    }
}
