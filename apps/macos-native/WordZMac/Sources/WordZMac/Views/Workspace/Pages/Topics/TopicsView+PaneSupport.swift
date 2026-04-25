import SwiftUI

extension TopicsView {
    func topicBadge(title: String, tone: TopicBadgeTone) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tone.background, in: Capsule())
    }
}

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            ForEach(data) { item in
                content(item)
            }
        }
    }
}

enum TopicBadgeTone {
    case blue
    case orange
    case secondary

    var foreground: Color {
        switch self {
        case .blue:
            return WordZTheme.primary
        case .orange:
            return .orange
        case .secondary:
            return .secondary
        }
    }

    var background: Color {
        switch self {
        case .blue:
            return WordZTheme.primary.opacity(0.12)
        case .orange:
            return Color.orange.opacity(0.16)
        case .secondary:
            return Color.white.opacity(0.06)
        }
    }
}
