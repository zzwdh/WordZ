import SwiftUI

extension SidebarView {
    func sidebarInformationRow(
        title: String,
        detail: String? = nil,
        symbol: String,
        isSelected: Bool = false
    ) -> some View {
        sidebarRowLabel(
            title: title,
            detail: detail,
            symbol: symbol,
            isSelected: isSelected
        )
    }

    func sidebarRowLabel(
        title: String,
        detail: String? = nil,
        symbol: String,
        isSelected: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .primary)
                    .lineLimit(1)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .imageScale(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func sidebarOverviewRow(
        title: String,
        detail: String,
        symbol: String
    ) -> some View {
        sidebarInformationRow(
            title: title,
            detail: detail,
            symbol: symbol
        )
    }

    func sidebarAnalysisRow(_ item: WorkspaceSidebarAnalysisSceneItem) -> some View {
        sidebarRowLabel(
            title: item.title,
            detail: nil,
            symbol: item.tab.symbolName,
            isSelected: item.isSelected || selectedRoute == WorkspaceMainRoute(tab: item.tab)
        )
        .contentShape(Rectangle())
    }

    func sidebarCorpusRow(
        slot: WorkspaceSidebarCorpusSlotSceneModel,
        symbol: String
    ) -> some View {
        sidebarInformationRow(
            title: slot.summary,
            detail: slot.title + " · " + slot.detail,
            symbol: symbol
        )
    }
}
