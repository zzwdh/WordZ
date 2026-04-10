import Foundation

struct UISettingsSnapshot: Equatable, Sendable {
    let showWelcomeScreen: Bool
    let restoreWorkspace: Bool
    let debugLogging: Bool

    static let `default` = UISettingsSnapshot(
        showWelcomeScreen: true,
        restoreWorkspace: true,
        debugLogging: false
    )

    init(json: JSONObject) {
        self.showWelcomeScreen = JSONFieldReader.bool(json, key: "showWelcomeScreen", fallback: true)
        self.restoreWorkspace = JSONFieldReader.bool(json, key: "restoreWorkspace", fallback: true)
        self.debugLogging = JSONFieldReader.bool(json, key: "debugLogging", fallback: false)
    }

    init(
        showWelcomeScreen: Bool,
        restoreWorkspace: Bool,
        debugLogging: Bool
    ) {
        self.showWelcomeScreen = showWelcomeScreen
        self.restoreWorkspace = restoreWorkspace
        self.debugLogging = debugLogging
    }

    func asJSONObject() -> JSONObject {
        [
            "showWelcomeScreen": showWelcomeScreen,
            "restoreWorkspace": restoreWorkspace,
            "debugLogging": debugLogging
        ]
    }
}
