import SwiftUI

enum UtilityPageContentScrollMode {
    case automatic
    case manual
}

struct UtilityPageScaffold<Header: View, Content: View>: View {
    private let header: Header
    private let content: Content
    private let scrollMode: UtilityPageContentScrollMode

    init(
        title _: String,
        scrollMode: UtilityPageContentScrollMode = .automatic,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header()
        self.content = content()
        self.scrollMode = scrollMode
    }

    var body: some View {
        Group {
            if Header.self == EmptyView.self {
                contentContainer
            } else {
                VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
                    header
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    content
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WordZTheme.pagePadding)
    }

    @ViewBuilder
    private var contentContainer: some View {
        switch scrollMode {
        case .automatic:
            GeometryReader { _ in
                ScrollView {
                    VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.trailing, WordZTheme.pageScrollIndicatorGutter)
                    .padding(.bottom, WordZTheme.pagePadding)
                }
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        case .manual:
            content
        }
    }
}

extension UtilityPageScaffold where Header == EmptyView {
    init(
        title: String,
        scrollMode: UtilityPageContentScrollMode = .automatic,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, scrollMode: scrollMode) {
            EmptyView()
        } content: {
            content()
        }
    }
}

struct WorkbenchFixedTopScrollContent<Fixed: View, Scrolling: View>: View {
    private let fixed: Fixed
    private let scrolling: Scrolling

    init(
        @ViewBuilder fixed: () -> Fixed,
        @ViewBuilder scrolling: () -> Scrolling
    ) {
        self.fixed = fixed()
        self.scrolling = scrolling()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
            fixed

            GeometryReader { _ in
                ScrollView {
                    VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
                        scrolling
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.trailing, WordZTheme.pageScrollIndicatorGutter)
                    .padding(.bottom, WordZTheme.pagePadding)
                }
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
