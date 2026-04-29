import SwiftUI

enum WorkbenchChartPalette {
    static let positive = Color(nsColor: .systemGreen)
    static let neutral = Color(nsColor: .systemGray)
    static let negative = Color(nsColor: .systemRed)
    static let accent = Color.accentColor
    static let secondary = Color.secondary
    static let reference = Color(nsColor: .systemIndigo)

    static func sentiment(_ label: SentimentLabel) -> Color {
        switch label {
        case .positive:
            return positive
        case .neutral:
            return neutral
        case .negative:
            return negative
        }
    }
}

struct WorkbenchChartLegendItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String?
    let color: Color

    init(id: String, title: String, value: String, detail: String? = nil, color: Color) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
        self.color = color
    }
}

struct WorkbenchChartLegend: View {
    let items: [WorkbenchChartLegendItem]

    var body: some View {
        if !items.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        legendItem(item)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        legendItem(item)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func legendItem(_ item: WorkbenchChartLegendItem) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(item.color)
                .frame(width: 8, height: 8)

            Text(item.title)
                .font(.caption.weight(.medium))

            Text(item.value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .lineLimit(1)
    }
}

struct WorkbenchChartSurface<Content: View>: View {
    @Environment(\.wordZVisualStyle) private var visualStyle

    let isEmpty: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let minHeight: CGFloat
    private let content: Content

    init(
        isEmpty: Bool = false,
        emptyTitle: String,
        emptySystemImage: String = "chart.bar.xaxis",
        minHeight: CGFloat = 260,
        @ViewBuilder content: () -> Content
    ) {
        self.isEmpty = isEmpty
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        Group {
            if isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: emptySystemImage)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(emptyTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: minHeight)
            } else {
                content
                    .frame(maxWidth: .infinity, minHeight: minHeight)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(surfaceBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(WordZTheme.surfaceStroke(for: visualStyle), lineWidth: 1)
        )
    }

    private var surfaceBackground: Color {
        switch visualStyle.tier {
        case .baseline, .chromeOnly:
            return WordZTheme.cardSecondaryBackground.opacity(0.72)
        case .glassSurface, .fullVisualRefresh:
            return WordZTheme.adaptiveCardBackground(for: visualStyle)
        }
    }
}
