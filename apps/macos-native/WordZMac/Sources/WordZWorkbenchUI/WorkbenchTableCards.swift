import SwiftUI
import WordZShared

package enum WorkbenchTablePreferences {
    package static let pinnedHeaderKey = "wordz.table.pinnedHeader.enabled"
    package static let minimumEmbeddedTableHeight: CGFloat = 360
    package static let defaultTableHeight: CGFloat = 430
    package static let maximumEmbeddedTableHeight: CGFloat = 560
}

package struct WorkbenchSectionCard<Content: View>: View {
    private let content: Content

    package init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    package var body: some View {
        GroupBox {
            content
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

package struct WorkbenchTableCard<Content: View, Trailing: View>: View {
    private let title: String?
    private let subtitle: String?
    private let trailing: Trailing
    private let content: Content

    package init(
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

    package var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Divider()

            content
                .frame(
                    maxWidth: .infinity,
                    minHeight: WorkbenchTablePreferences.minimumEmbeddedTableHeight,
                    idealHeight: WorkbenchTablePreferences.defaultTableHeight,
                    maxHeight: WorkbenchTablePreferences.maximumEmbeddedTableHeight,
                    alignment: .topLeading
                )
                .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var hasHeaderText: Bool {
        title?.isEmpty == false || subtitle?.isEmpty == false
    }
}

extension WorkbenchTableCard where Trailing == EmptyView {
    package init(
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

package struct WorkbenchPinnedHeaderToggle: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @AppStorage(WorkbenchTablePreferences.pinnedHeaderKey) private var isPinned = true

    package init() {}

    package var body: some View {
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
