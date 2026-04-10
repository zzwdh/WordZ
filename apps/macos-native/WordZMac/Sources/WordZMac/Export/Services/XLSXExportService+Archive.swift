import Foundation

extension XLSXExportService {
    static func writeArchiveFiles(snapshot: NativeTableExportSnapshot, into root: URL) throws {
        let sheetName = sanitizedSheetName(snapshot.suggestedBaseName)
        let worksheetRows = worksheetRows(snapshot: snapshot)
        let timestamp = iso8601Timestamp()

        try FileManager.default.createDirectory(at: root.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docProps"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)

        try writeXML(contentTypesXML(), to: root.appendingPathComponent("[Content_Types].xml"))
        try writeXML(rootRelationshipsXML(), to: root.appendingPathComponent("_rels/.rels"))
        try writeXML(appPropertiesXML(), to: root.appendingPathComponent("docProps/app.xml"))
        try writeXML(corePropertiesXML(timestamp: timestamp), to: root.appendingPathComponent("docProps/core.xml"))
        try writeXML(workbookXML(sheetName: sheetName), to: root.appendingPathComponent("xl/workbook.xml"))
        try writeXML(workbookRelationshipsXML(), to: root.appendingPathComponent("xl/_rels/workbook.xml.rels"))
        try writeXML(stylesXML(), to: root.appendingPathComponent("xl/styles.xml"))
        try writeXML(
            worksheetXML(
                rows: worksheetRows,
                headerRowIndex: max(snapshot.metadataLines.count + 1, 1)
            ),
            to: root.appendingPathComponent("xl/worksheets/sheet1.xml")
        )
    }

    static func writeXML(_ xml: String, to url: URL) throws {
        try xml.data(using: .utf8)?.write(to: url, options: .atomic) ?? {
            throw NSError(
                domain: "WordZMac.XLSXExportService",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "无法生成 Excel XML 数据。"]
            )
        }()
    }

    static func run(_ process: Process) throws -> Int32 {
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }
        try process.run()
        group.wait()
        return process.terminationStatus
    }
}
