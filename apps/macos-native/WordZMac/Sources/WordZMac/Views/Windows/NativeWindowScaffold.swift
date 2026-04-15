import AppKit
import SwiftUI

struct NativeWindowHeader<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let accessory: Accessory

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        AdaptiveHeaderSurface {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)
                accessory
            }
        }
    }
}

extension NativeWindowHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct NativeWindowSection<Content: View>: View {
    @Environment(\.wordZVisualStyle) private var visualStyle

    let title: String
    let subtitle: String?
    let content: Content

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
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if visualStyle.usesAdaptiveSectionSurface {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(AdaptiveInspectorSurfaceModifier())
            } else {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct NativeMetricTile: View {
    @Environment(\.wordZVisualStyle) private var visualStyle

    let title: String
    let value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.monospacedDigit())

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(WordZTheme.adaptiveCardBackground(for: visualStyle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(WordZTheme.surfaceStroke(for: visualStyle), lineWidth: visualStyle.tier == .baseline ? 0 : 1)
        )
    }
}

private struct AdaptiveInspectorSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        AdaptiveInspectorSurface {
            content
        }
    }
}
