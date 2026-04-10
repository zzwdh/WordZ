import SwiftUI

struct WorkbenchEmptyStateCard<Actions: View>: View {
    let title: String
    let systemImage: String
    let message: String
    let suggestions: [String]
    private let actions: Actions

    init(
        title: String,
        systemImage: String,
        message: String,
        suggestions: [String] = [],
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.suggestions = suggestions
        self.actions = actions()
    }

    var body: some View {
        WorkbenchSectionCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(suggestion)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    actions
                }

                Spacer(minLength: 0)
            }
        }
    }
}

extension WorkbenchEmptyStateCard where Actions == EmptyView {
    init(title: String, systemImage: String, message: String, suggestions: [String] = []) {
        self.init(title: title, systemImage: systemImage, message: message, suggestions: suggestions) {
            EmptyView()
        }
    }
}
