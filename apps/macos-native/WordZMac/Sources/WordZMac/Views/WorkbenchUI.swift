import SwiftUI

struct WorkbenchSectionCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct WorkbenchToolbarSection<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
    }
}

struct WorkbenchHeaderCard<Trailing: View>: View {
    let title: String
    let subtitle: String?
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        WorkbenchSectionCard {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 16)
                trailing
            }
        }
    }
}

extension WorkbenchHeaderCard where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct WorkbenchMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?

    init(title: String, value: String, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WorkbenchPaneCard<Content: View>: View {
    let title: String
    let subtitle: String?
    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

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
        .background(
            tone.backgroundTint,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tone.tint.opacity(0.25), lineWidth: 1)
        )
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

    var backgroundTint: Color {
        switch self {
        case .info:
            return Color.accentColor.opacity(0.1)
        case .warning:
            return Color.orange.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        }
    }
}

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

struct WorkbenchColumnMenu<Key: Identifiable>: View {
    let title: String
    let keys: [Key]
    let label: (Key) -> String
    let isVisible: (Key) -> Bool
    let onToggle: (Key) -> Void

    var body: some View {
        Menu(title) {
            ForEach(keys) { key in
                Button {
                    onToggle(key)
                } label: {
                    Label(
                        label(key),
                        systemImage: isVisible(key) ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        }
    }
}
