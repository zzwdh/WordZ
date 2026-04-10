import SwiftUI

enum WorkbenchTablePreferences {
    static let pinnedHeaderKey = "wordz.table.pinnedHeader.enabled"
    static let defaultTableHeight: CGFloat = 430
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

struct WorkbenchTableCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    WorkbenchPinnedHeaderToggle()
                }

                content
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 360,
                        idealHeight: WorkbenchTablePreferences.defaultTableHeight,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .layoutPriority(1)
            }
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
            Label(
                isPinned
                    ? wordZText("固定表头", "Sticky Header", mode: languageMode)
                    : wordZText("表头可隐藏", "Header Unpinned", mode: languageMode),
                systemImage: isPinned ? "pin.fill" : "pin.slash"
            )
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(
            isPinned
                ? wordZText("表头会固定在表格顶部，数据区域单独滚动。", "Keep the header fixed while the data region scrolls independently.", mode: languageMode)
                : wordZText("关闭后只保留内容滚动，不再固定显示表头。", "Turn this off to stop pinning the header while scrolling.", mode: languageMode)
        )
    }
}
