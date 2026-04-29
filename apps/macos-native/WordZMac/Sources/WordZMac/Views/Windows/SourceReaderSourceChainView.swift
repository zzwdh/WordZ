import SwiftUI

struct SourceReaderSourceChainView: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    let items: [SourceReaderSourceChainItem]
    let title: String?
    let showsDetails: Bool

    init(
        items: [SourceReaderSourceChainItem],
        title: String? = nil,
        showsDetails: Bool = false
    ) {
        self.items = items
        self.title = title
        self.showsDetails = showsDetails
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if let title {
                    Label(title, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ViewThatFits(in: .horizontal) {
                    horizontalChain
                    verticalChain
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    private var horizontalChain: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                chainItem(item)

                if index < items.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, showsDetails ? 18 : 8)
                }
            }
        }
    }

    private var verticalChain: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    chainItem(item)

                    if index < items.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func chainItem(_ item: SourceReaderSourceChainItem) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(item.value)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(item.isCurrent ? Color.accentColor : WordZTheme.textPrimary)
                    .lineLimit(showsDetails ? 2 : 1)
                if showsDetails, let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        } icon: {
            Image(systemName: item.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.isCurrent ? Color.accentColor : .secondary)
                .frame(width: 16)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: showsDetails ? .infinity : nil, alignment: .leading)
        .background(
            Capsule()
                .fill(item.isCurrent ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(item.isCurrent ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private var accessibilitySummary: String {
        let prefix = title ?? wordZText("高亮来源链", "Highlight Source Chain", mode: languageMode)
        return ([prefix] + items.map { "\($0.title): \($0.value)" }).joined(separator: ". ")
    }
}
