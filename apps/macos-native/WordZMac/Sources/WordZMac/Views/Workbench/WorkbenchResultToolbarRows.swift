import SwiftUI

struct WorkbenchResultsToolbarSection<Leading: View, Trailing: View, LeadingControls: View, TrailingControls: View>: View {
    private let leading: Leading
    private let trailing: Trailing
    private let leadingControls: LeadingControls
    private let trailingControls: TrailingControls

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder leadingControls: () -> LeadingControls,
        @ViewBuilder trailingControls: () -> TrailingControls
    ) {
        self.leading = leading()
        self.trailing = trailing()
        self.leadingControls = leadingControls()
        self.trailingControls = trailingControls()
    }

    var body: some View {
        WorkbenchToolbarSection {
            WorkbenchResultHeaderRow {
                leading
            } trailing: {
                trailing
            }

            WorkbenchResultControlsRow {
                leadingControls
            } trailing: {
                trailingControls
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
