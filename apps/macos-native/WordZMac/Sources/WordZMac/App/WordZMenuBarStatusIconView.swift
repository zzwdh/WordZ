import SwiftUI

enum WordZMenuBarIconState: Equatable {
    case idle
    case tasksRunning
    case updateReady
}

struct WordZMenuBarStatusIconView: View {
    @ObservedObject var status: WordZMenuBarStatusModel

    var body: some View {
        Image(nsImage: WordZMenuBarIcon.image(state: status.iconState))
            .accessibilityLabel("WordZ")
    }
}
