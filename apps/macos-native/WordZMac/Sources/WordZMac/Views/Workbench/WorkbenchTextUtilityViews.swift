import AppKit
import SwiftUI

struct WorkbenchCopyTextButton: View {
    let title: String
    let systemImage: String
    let text: String

    init(title: String, systemImage: String = "doc.on.doc", text: String) {
        self.title = title
        self.systemImage = systemImage
        self.text = text
    }

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

struct WorkbenchConcordanceLineView: View {
    let leftContext: String
    let keyword: String
    let rightContext: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(leftContext)
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)

            Text(keyword)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
                .fixedSize(horizontal: true, vertical: false)

            Text(rightContext)
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }
}
