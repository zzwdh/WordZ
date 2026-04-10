import Foundation

struct NativePersistedUISettings: Codable, Equatable {
    let showWelcomeScreen: Bool
    let restoreWorkspace: Bool
    let debugLogging: Bool

    static let `default` = NativePersistedUISettings(
        showWelcomeScreen: true,
        restoreWorkspace: true,
        debugLogging: false
    )

    var uiSettings: UISettingsSnapshot {
        UISettingsSnapshot(
            showWelcomeScreen: showWelcomeScreen,
            restoreWorkspace: restoreWorkspace,
            debugLogging: debugLogging
        )
    }
}
