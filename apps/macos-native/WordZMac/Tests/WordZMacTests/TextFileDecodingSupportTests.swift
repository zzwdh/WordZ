import XCTest
@testable import WordZWorkspaceCore

final class TextFileDecodingSupportTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDown() {
        let fileManager = FileManager.default
        temporaryFiles.forEach { try? fileManager.removeItem(at: $0) }
        temporaryFiles.removeAll()
        super.tearDown()
    }

    func testDecodeRecognizesUTF16LittleEndianWithoutByteOrderMark() throws {
        let data = try XCTUnwrap("Alpha beta gamma".data(using: .utf16LittleEndian))

        let document = try TextFileDecodingSupport.decode(data: data, sourceName: "sample.txt")

        XCTAssertEqual(document.text, "Alpha beta gamma")
        XCTAssertEqual(document.encodingName, "utf-16le")
    }

    func testReadImportedTextDocumentRejectsUnsupportedBinaryExtensionBeforeReading() {
        let url = URL(fileURLWithPath: "/tmp/sample.png")

        XCTAssertThrowsError(try TextFileDecodingSupport.readImportedTextDocument(at: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("暂不支持读取该语料文件格式"))
        }
    }

    func testReadTextDocumentDecodesLargeUTF8File() throws {
        let content = Array(repeating: "Alpha beta 词语🙂 delta", count: 30_000).joined(separator: "\n")
        let url = makeTemporaryFileURL(named: "large-utf8.txt")
        try content.write(to: url, atomically: true, encoding: .utf8)

        let document = try TextFileDecodingSupport.readTextDocument(at: url)

        XCTAssertEqual(document.text, content)
        XCTAssertEqual(document.encodingName, "utf-8")
    }

    func testReadTextDocumentDecodesLargeUTF8FileWithMultibyteCharactersAcrossChunks() throws {
        let content = String(repeating: "a", count: 70_000) + Array(repeating: "边界🙂测试", count: 15_000).joined()
        let url = makeTemporaryFileURL(named: "large-utf8-multibyte.txt")
        try content.write(to: url, atomically: true, encoding: .utf8)

        let document = try TextFileDecodingSupport.readTextDocument(at: url)

        XCTAssertEqual(document.text, content)
        XCTAssertEqual(document.encodingName, "utf-8")
    }

    func testReadTextDocumentDecodesLargeUTF16LittleEndianFileWithoutBOM() throws {
        let content = Array(repeating: "Alpha beta gamma delta", count: 24_000).joined(separator: "\n")
        let url = makeTemporaryFileURL(named: "large-utf16le.txt")
        let data = try XCTUnwrap(content.data(using: .utf16LittleEndian))
        try data.write(to: url)

        let document = try TextFileDecodingSupport.readTextDocument(at: url)

        XCTAssertEqual(document.text, content)
        XCTAssertEqual(document.encodingName, "utf-16le")
    }

    private func makeTemporaryFileURL(named fileName: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-text-decode-\(UUID().uuidString)-\(fileName)", isDirectory: false)
        temporaryFiles.append(url)
        return url
    }
}
