import Foundation

struct AppInfoSummary: Equatable, Sendable {
    let name: String
    let version: String
    let help: [String]
    let releaseNotes: [String]
    let userDataDir: String

    init(json: JSONObject) {
        self.name = JSONFieldReader.string(json, key: "name", fallback: "WordZ")
        self.version = JSONFieldReader.string(json, key: "version")
        self.help = (json["help"] as? [String]) ?? []
        self.releaseNotes = (json["releaseNotes"] as? [String]) ?? []
        self.userDataDir = JSONFieldReader.string(json, key: "userDataDir")
    }
}
