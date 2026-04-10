import SwiftUI

enum WorkbenchPageHeaderLayout {
    case trailingStack
    case inline
}

struct WorkbenchPageHeaderActions<Actions: View>: View {
    let summary: String
    let layout: WorkbenchPageHeaderLayout
    private let actions: Actions

    init(
        summary: String,
        layout: WorkbenchPageHeaderLayout,
        @ViewBuilder actions: () -> Actions
    ) {
        self.summary = summary
        self.layout = layout
        self.actions = actions()
    }

    var body: some View {
        switch layout {
        case .trailingStack:
            VStack(alignment: .trailing, spacing: 6) {
                summaryLabel
                actions
            }
        case .inline:
            HStack(spacing: 8) {
                summaryLabel
                actions
            }
        }
    }

    private var summaryLabel: some View {
        Text(summary)
            .font(.caption)
            .foregroundStyle(WordZTheme.textSecondary)
            .lineLimit(1)
    }
}
