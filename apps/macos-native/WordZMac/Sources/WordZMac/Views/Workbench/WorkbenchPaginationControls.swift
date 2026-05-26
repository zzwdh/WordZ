import SwiftUI

struct WorkbenchPaginationControls: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let canGoBackward: Bool
    let canGoForward: Bool
    let rangeLabel: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onPrevious()
            } label: {
                Label(wordZText("上一页", "Previous", mode: languageMode), systemImage: "chevron.left")
            }
            .disabled(!canGoBackward)

            Text(rangeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                onNext()
            } label: {
                Label(wordZText("下一页", "Next", mode: languageMode), systemImage: "chevron.right")
            }
            .disabled(!canGoForward)
        }
    }
}
