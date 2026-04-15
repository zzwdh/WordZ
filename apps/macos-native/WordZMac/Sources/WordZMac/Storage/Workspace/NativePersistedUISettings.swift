import Foundation

struct NativePersistedUISettings: Codable, Equatable {
    let showWelcomeScreen: Bool
    let restoreWorkspace: Bool
    let debugLogging: Bool
    let recentMetadataSourceLabels: [String]
    let recentCorpusSetIDs: [String]

    static let `default` = NativePersistedUISettings(
        showWelcomeScreen: true,
        restoreWorkspace: true,
        debugLogging: false,
        recentMetadataSourceLabels: [],
        recentCorpusSetIDs: []
    )

    var uiSettings: UISettingsSnapshot {
        UISettingsSnapshot(
            showWelcomeScreen: showWelcomeScreen,
            restoreWorkspace: restoreWorkspace,
            debugLogging: debugLogging,
            recentMetadataSourceLabels: recentMetadataSourceLabels,
            recentCorpusSetIDs: recentCorpusSetIDs
        )
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.showWelcomeScreen = try container.decodeIfPresent(Bool.self, forKey: .showWelcomeScreen) ?? true
        self.restoreWorkspace = try container.decodeIfPresent(Bool.self, forKey: .restoreWorkspace) ?? true
        self.debugLogging = try container.decodeIfPresent(Bool.self, forKey: .debugLogging) ?? false
        self.recentMetadataSourceLabels = try container.decodeIfPresent([String].self, forKey: .recentMetadataSourceLabels) ?? []
        self.recentCorpusSetIDs = try container.decodeIfPresent([String].self, forKey: .recentCorpusSetIDs) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case showWelcomeScreen
        case restoreWorkspace
        case debugLogging
        case recentMetadataSourceLabels
        case recentCorpusSetIDs
    }
}
