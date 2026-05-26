import SwiftUI

struct WorkbenchGuardedPageSizePicker<PageSize: InteractiveAllPageSizing & CaseIterable & Identifiable & Hashable>: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let title: String
    @Binding var selection: PageSize
    let totalRows: Int
    let label: (PageSize) -> String
    let maxWidth: CGFloat

    init(
        title: String,
        selection: Binding<PageSize>,
        totalRows: Int,
        maxWidth: CGFloat = 300,
        label: @escaping (PageSize) -> String
    ) {
        self.title = title
        self._selection = selection
        self.totalRows = totalRows
        self.label = label
        self.maxWidth = maxWidth
    }

    private var disablesInteractiveAllPageSize: Bool {
        !PageSize.allowsInteractiveAllPageSize(totalRows: totalRows)
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(Array(PageSize.allCases)) { size in
                Text(label(size))
                    .tag(size)
                    .disabled(disablesInteractiveAllPageSize && size.isAllSelection)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: maxWidth)
        .help(disablesInteractiveAllPageSize ? wordZText("结果较大时，“全部”页大小会被禁用，以保持界面响应。", "For large result sets, the All page size is disabled to keep the UI responsive.", mode: languageMode) : "")
    }
}

struct WorkbenchTablePageSizeControls<
    PageSize: InteractiveAllPageSizing & CaseIterable & Identifiable & Hashable
>: View {
    let title: String
    @Binding var selectedPageSize: PageSize
    let totalRows: Int
    let label: (PageSize) -> String

    var body: some View {
        WorkbenchAdaptiveControlCluster {
            WorkbenchGuardedPageSizePicker(
                title: title,
                selection: $selectedPageSize,
                totalRows: totalRows,
                label: label
            )
        }
    }
}
