import Foundation

struct UISettingsSnapshot: Equatable, Sendable {
    let showWelcomeScreen: Bool
    let restoreWorkspace: Bool
    let debugLogging: Bool
    let recentMetadataSourceLabels: [String]
    let recentCorpusSetIDs: [String]

    static let `default` = UISettingsSnapshot(
        showWelcomeScreen: true,
        restoreWorkspace: true,
        debugLogging: false,
        recentMetadataSourceLabels: [],
        recentCorpusSetIDs: []
    )

    init(json: JSONObject) {
        self.showWelcomeScreen = JSONFieldReader.bool(json, key: "showWelcomeScreen", fallback: true)
        self.restoreWorkspace = JSONFieldReader.bool(json, key: "restoreWorkspace", fallback: true)
        self.debugLogging = JSONFieldReader.bool(json, key: "debugLogging", fallback: false)
        self.recentMetadataSourceLabels = JSONFieldReader.stringArray(json, key: "recentMetadataSourceLabels")
        self.recentCorpusSetIDs = JSONFieldReader.stringArray(json, key: "recentCorpusSetIDs")
    }

    init(
        showWelcomeScreen: Bool,
        restoreWorkspace: Bool,
        debugLogging: Bool,
        recentMetadataSourceLabels: [String] = [],
        recentCorpusSetIDs: [String] = []
    ) {
        self.showWelcomeScreen = showWelcomeScreen
        self.restoreWorkspace = restoreWorkspace
        self.debugLogging = debugLogging
        self.recentMetadataSourceLabels = recentMetadataSourceLabels
        self.recentCorpusSetIDs = recentCorpusSetIDs
    }

    func asJSONObject() -> JSONObject {
        [
            "showWelcomeScreen": showWelcomeScreen,
            "restoreWorkspace": restoreWorkspace,
            "debugLogging": debugLogging,
            "recentMetadataSourceLabels": recentMetadataSourceLabels,
            "recentCorpusSetIDs": recentCorpusSetIDs
        ]
    }
}
