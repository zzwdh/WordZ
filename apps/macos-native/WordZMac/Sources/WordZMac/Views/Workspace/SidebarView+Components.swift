import SwiftUI

extension SidebarView {
    func sidebarInformationRow(
        title: String,
        detail: String? = nil,
        symbol: String
    ) -> some View {
        sidebarRowLabel(
            title: title,
            detail: detail,
            symbol: symbol
        )
    }

    func sidebarRowLabel(
        title: String,
        detail: String? = nil,
        symbol: String
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)
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
            detail: item.subtitle,
            symbol: item.tab.symbolName
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard item.isEnabled else { return }
            selectedRoute = WorkspaceMainRoute(tab: item.tab)
        }
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
