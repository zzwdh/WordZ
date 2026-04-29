import SwiftUI

enum WorkbenchTablePreferences {
    static let pinnedHeaderKey = "wordz.table.pinnedHeader.enabled"
    static let minimumEmbeddedTableHeight: CGFloat = 360
    static let defaultTableHeight: CGFloat = 430
    static let maximumEmbeddedTableHeight: CGFloat = 560
}

struct WorkbenchSectionCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GroupBox {
            content
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorkbenchTableCard<Content: View, Trailing: View>: View {
    private let title: String?
    private let subtitle: String?
    private let trailing: Trailing
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if hasHeaderText {
                        VStack(alignment: .leading, spacing: 2) {
                            if let title, !title.isEmpty {
                                Text(title)
                                    .font(.subheadline.weight(.semibold))
                            }
                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    trailing
                    WorkbenchPinnedHeaderToggle()
                }
                .padding(.horizontal, 2)

                content
                    .frame(
                        maxWidth: .infinity,
                        minHeight: WorkbenchTablePreferences.minimumEmbeddedTableHeight,
                        idealHeight: WorkbenchTablePreferences.defaultTableHeight,
                        maxHeight: WorkbenchTablePreferences.maximumEmbeddedTableHeight,
                        alignment: .topLeading
                    )
                    .padding(6)
                    .background(
                        WordZTheme.cardSecondaryBackground.opacity(0.68),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(WordZTheme.divider.opacity(0.45), lineWidth: 1)
                    )
                    .clipped()
            }
        }
    }

    private var hasHeaderText: Bool {
        title?.isEmpty == false || subtitle?.isEmpty == false
    }
}

extension WorkbenchTableCard where Trailing == EmptyView {
    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, subtitle: subtitle) {
            EmptyView()
        } content: {
            content()
        }
    }
}

struct WorkbenchPinnedHeaderToggle: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @AppStorage(WorkbenchTablePreferences.pinnedHeaderKey) private var isPinned = true

    var body: some View {
        Button {
            isPinned.toggle()
        } label: {
            Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                .font(.caption.weight(.semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(accessibilityLabel)
        .help(
            isPinned
                ? wordZText("表头会固定在表格顶部，数据区域单独滚动。", "Keep the header fixed while the data region scrolls independently.", mode: languageMode)
                : wordZText("关闭后只保留内容滚动，不再固定显示表头。", "Turn this off to stop pinning the header while scrolling.", mode: languageMode)
        )
    }

    private var accessibilityLabel: String {
        isPinned
            ? wordZText("固定表头", "Sticky Header", mode: languageMode)
            : wordZText("表头可隐藏", "Header Unpinned", mode: languageMode)
    }
}
