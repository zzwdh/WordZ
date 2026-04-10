import SwiftUI

struct HelpCenterWindowView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel

    var body: some View {
        ScrollView {
            helpCenterWindowContent
        }
        .bindWindowRoute(.help)
        .frame(minWidth: 520, minHeight: 420)
    }

    func helpRow(_ title: String, shortcut: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
