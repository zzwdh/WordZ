import SwiftUI

struct AboutWindowView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel

    var body: some View {
        ScrollView {
            aboutWindowContent
        }
        .bindWindowRoute(.about)
        .frame(minWidth: 460, minHeight: 360)
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
