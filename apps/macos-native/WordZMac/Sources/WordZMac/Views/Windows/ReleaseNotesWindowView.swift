import SwiftUI

struct ReleaseNotesWindowView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel

    var body: some View {
        ScrollView {
            releaseNotesWindowContent
        }
        .adaptiveWindowScaffold(for: .releaseNotes)
        .bindWindowRoute(.releaseNotes, titleProvider: { mode in
            NativeWindowRoute.releaseNotes.title(in: mode)
        })
        .focusedValue(\.workspaceCommandContext, workspace.commandContext(for: .releaseNotes))
        .frame(minWidth: 560, minHeight: 420)
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
