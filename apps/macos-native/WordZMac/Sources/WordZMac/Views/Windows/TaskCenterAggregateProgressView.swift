import SwiftUI

enum TaskCenterAggregateProgressStyle {
    case content
    case titlebarAccessory
}

struct TaskCenterAggregateProgressView: View {
    let progress: Double
    let summary: String
    let style: TaskCenterAggregateProgressStyle

    var body: some View {
        switch style {
        case .content:
            AdaptiveToolbarSurface {
                progressContent(maxWidth: .infinity, alignment: .leading)
            }
        case .titlebarAccessory:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                progressContent(maxWidth: 240, alignment: .trailing)
            }
            .padding(.trailing, 20)
            .padding(.top, 2)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func progressContent(
        maxWidth: CGFloat,
        alignment: Alignment
    ) -> some View {
        VStack(alignment: style == .titlebarAccessory ? .trailing : .leading, spacing: 4) {
            ProgressView(value: progress)
                .controlSize(.small)
                .frame(maxWidth: maxWidth)
                .tint(.accentColor)

            Text(summary)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: maxWidth, alignment: alignment)
    }
}
