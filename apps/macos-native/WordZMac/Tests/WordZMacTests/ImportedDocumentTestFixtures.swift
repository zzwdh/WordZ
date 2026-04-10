import AppKit
import CoreGraphics
import CoreText
import Foundation

enum ImportedDocumentTestFixtures {
    static func writeDOCX(text: String, to url: URL) throws {
        let attributedString = NSAttributedString(string: text)
        let data = try attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        try data.write(to: url, options: .atomic)
    }

    static func writePDF(text: String, to url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw fixtureError("无法创建 PDF 测试文档。")
        }

        context.beginPDFPage(nil)
        if !text.isEmpty {
            let frame = CGRect(x: 72, y: 72, width: 468, height: 648)
            let attributedString = NSAttributedString(string: text)
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
            let path = CGPath(rect: frame, transform: nil)
            let frameRef = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: 0, length: attributedString.length),
                path,
                nil
            )
            context.textMatrix = .identity
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)
            CTFrameDraw(frameRef, context)
        }
        context.endPDFPage()
        context.closePDF()
    }

    static func fixtureError(_ message: String) -> NSError {
        NSError(
            domain: "WordZMacTests.ImportedDocumentTestFixtures",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
