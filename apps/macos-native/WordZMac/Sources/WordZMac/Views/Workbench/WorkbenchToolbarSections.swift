import SwiftUI

struct WorkbenchToolbarSection<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
    }
}

struct WorkbenchAdaptiveControls<Wide: View, Compact: View>: View {
    private let wide: Wide
    private let compact: Compact

    init(
        @ViewBuilder wide: () -> Wide,
        @ViewBuilder compact: () -> Compact
    ) {
        self.wide = wide()
        self.compact = compact()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wide
            compact
        }
    }
}

struct WorkbenchAdaptiveControlCluster<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        WorkbenchAdaptiveControls {
            HStack(spacing: 12) {
                content
            }
        } compact: {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
    }
}

struct WorkbenchSearchToolbarSection<Content: View>: View {
    @Binding var searchOptions: SearchOptionsState
    @Binding var stopwordFilter: StopwordFilterState
    @Binding var isEditingStopwords: Bool
    private let content: Content
    private let middle: AnyView
    private let footer: AnyView

    init(
        searchOptions: Binding<SearchOptionsState>,
        stopwordFilter: Binding<StopwordFilterState>,
        isEditingStopwords: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self._searchOptions = searchOptions
        self._stopwordFilter = stopwordFilter
        self._isEditingStopwords = isEditingStopwords
        self.content = content()
        self.middle = AnyView(EmptyView())
        self.footer = AnyView(EmptyView())
    }

    init<Middle: View>(
        searchOptions: Binding<SearchOptionsState>,
        stopwordFilter: Binding<StopwordFilterState>,
        isEditingStopwords: Binding<Bool>,
        @ViewBuilder content: () -> Content,
        @ViewBuilder middle: () -> Middle
    ) {
        self._searchOptions = searchOptions
        self._stopwordFilter = stopwordFilter
        self._isEditingStopwords = isEditingStopwords
        self.content = content()
        self.middle = AnyView(middle())
        self.footer = AnyView(EmptyView())
    }

    init<Middle: View, Footer: View>(
        searchOptions: Binding<SearchOptionsState>,
        stopwordFilter: Binding<StopwordFilterState>,
        isEditingStopwords: Binding<Bool>,
        @ViewBuilder content: () -> Content,
        @ViewBuilder middle: () -> Middle,
        @ViewBuilder footer: () -> Footer
    ) {
        self._searchOptions = searchOptions
        self._stopwordFilter = stopwordFilter
        self._isEditingStopwords = isEditingStopwords
        self.content = content()
        self.middle = AnyView(middle())
        self.footer = AnyView(footer())
    }

    var body: some View {
        WorkbenchToolbarSection {
            content
            middle
            SearchOptionTogglesView(options: $searchOptions)
            StopwordControlsView(
                filter: $stopwordFilter,
                isEditorPresented: $isEditingStopwords
            )
            footer
        }
    }
}
