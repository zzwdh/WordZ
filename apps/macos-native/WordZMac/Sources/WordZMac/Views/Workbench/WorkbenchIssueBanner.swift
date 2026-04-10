import SwiftUI

struct WorkbenchIssueBanner<Actions: View>: View {
    let tone: WorkspaceIssueBannerTone
    let title: String
    let message: String
    private let actions: Actions

    init(
        tone: WorkspaceIssueBannerTone,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.tone = tone
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: tone.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tone.tint)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                actions
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .workbenchCardChrome(cornerRadius: 14)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tone.tint)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 6)
        }
    }
}

extension WorkbenchIssueBanner where Actions == EmptyView {
    init(tone: WorkspaceIssueBannerTone, title: String, message: String) {
        self.init(tone: tone, title: title, message: message) {
            EmptyView()
        }
    }
}

private extension WorkspaceIssueBannerTone {
    var symbolName: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info:
            return .accentColor
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
