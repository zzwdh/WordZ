import SwiftUI

struct UtilityPageScaffold<Header: View, Content: View>: View {
    private let title: String
    private let header: Header
    private let content: Content

    init(
        title: String,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.header = header()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                header
            }

            Divider()

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WordZTheme.pagePadding)
    }
}

extension UtilityPageScaffold where Header == EmptyView {
    init(title: String, @ViewBuilder content: () -> Content) {
        self.init(title: title) {
            EmptyView()
        } content: {
            content()
        }
    }
}
