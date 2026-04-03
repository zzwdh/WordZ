import AppKit
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

struct WorkbenchResultHeaderRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                leading
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                trailing
            }
        }
    }
}

struct WorkbenchResultControlsRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            leading
            Spacer(minLength: 12)
            trailing
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

struct WorkbenchMethodNoteCard: View {
    let title: String
    let summary: String
    let notes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "text.book.closed")
                .font(.headline)
            Text(summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.top, 2)
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

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

struct WorkbenchTaskPreviewStrip: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: NativeTaskCenterSceneModel

    var body: some View {
        WorkbenchSectionCard {
            HStack(spacing: 12) {
                Label(activeTitle, systemImage: "bolt.horizontal.circle")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                if let aggregateProgress {
                    ProgressView(value: aggregateProgress)
                        .tint(.accentColor)
                        .frame(maxWidth: 220)
                }

                Text(activeDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let aggregateProgress {
                    Text("\(Int((aggregateProgress * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(scene.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var aggregateProgress: Double? {
        scene.aggregateProgress
    }

    private var activeItem: NativeBackgroundTaskItem? {
        scene.highlightedItems.first
    }

    private var activeTitle: String {
        activeItem?.title ?? t("后台任务", "Background Tasks")
    }

    private var activeDetail: String {
        if let activeItem {
            return activeItem.detail
        }
        return scene.summary
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
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

struct WorkbenchCopyTextButton: View {
    let title: String
    let systemImage: String
    let text: String

    init(title: String, systemImage: String = "doc.on.doc", text: String) {
        self.title = title
        self.systemImage = systemImage
        self.text = text
    }

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

struct WorkbenchConcordanceLineView: View {
    let leftContext: String
    let keyword: String
    let rightContext: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(leftContext)
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)

            Text(keyword)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
                .fixedSize(horizontal: true, vertical: false)

            Text(rightContext)
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }
}
