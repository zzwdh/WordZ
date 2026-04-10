import SwiftUI

struct ReleaseNotesWindowView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel

    var body: some View {
        ScrollView {
            releaseNotesWindowContent
        }
        .bindWindowRoute(.releaseNotes)
        .frame(minWidth: 560, minHeight: 420)
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
