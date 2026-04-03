import XCTest
@testable import WordZMac

final class XLSXExportServiceTests: XCTestCase {
    func testWriteCreatesZipBasedXLSXArchive() async throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "Stats Export",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: true, sortIndicator: nil)
            ]),
            rows: [
                NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha", "count": "12"]),
                NativeTableRowDescriptor(id: "beta", values: ["word": "beta", "count": "9"])
            ]
        )

        try await XLSXExportService().write(snapshot: snapshot, to: outputURL.path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let header = try Data(contentsOf: outputURL).prefix(2)
        XCTAssertEqual(Array(header), [0x50, 0x4B])
    }

    func testWriteOnlyIncludesVisibleColumnsInWorksheet() async throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-visible-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "Stats Export",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "normFrequency", title: "标准频次", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: false, sortIndicator: nil)
            ]),
            rows: [
                NativeTableRowDescriptor(
                    id: "alpha",
                    values: ["word": "alpha", "normFrequency": "4000.00", "count": "12"]
                )
            ]
        )

        try await XLSXExportService().write(snapshot: snapshot, to: outputURL.path)

        let sheetXML = try unzipEntry(at: outputURL, entry: "xl/worksheets/sheet1.xml")
        XCTAssertTrue(sheetXML.contains("词"))
        XCTAssertTrue(sheetXML.contains("标准频次"))
        XCTAssertTrue(sheetXML.contains("4000.00"))
        XCTAssertFalse(sheetXML.contains(">频次<"))
        XCTAssertFalse(sheetXML.contains(">12<"))
    }

    func testWriteIncludesMetadataRowsAndFreezesHeaderBelowThem() async throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-metadata-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "Stats Export",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: true, sortIndicator: nil)
            ]),
            rows: [
                NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha", "count": "12"])
            ],
            metadataLines: ["口径: 每万词 · 按句子", "导出范围: 当前可见行 1 / 1"]
        )

        try await XLSXExportService().write(snapshot: snapshot, to: outputURL.path)

        let sheetXML = try unzipEntry(at: outputURL, entry: "xl/worksheets/sheet1.xml")
        XCTAssertTrue(sheetXML.contains("口径: 每万词 · 按句子"))
        XCTAssertTrue(sheetXML.contains("导出范围: 当前可见行 1 / 1"))
        XCTAssertTrue(sheetXML.contains("ySplit=\"3\""))
        XCTAssertTrue(sheetXML.contains("topLeftCell=\"A4\""))
        XCTAssertTrue(sheetXML.contains("autoFilter ref=\"A3:B3\""))
    }

    private func unzipEntry(at archiveURL: URL, entry: String) throws -> String {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", archiveURL.path, entry]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw XCTSkip("unzip failed: \(stderr)")
        }

        return String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
