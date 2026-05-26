import Foundation

extension XLSXExportService {
    static func writeArchiveFiles(snapshot: NativeTableExportSnapshot, into root: URL) throws {
        let timestamp = iso8601Timestamp()
        let sheetNames = workbookSheetNames()
        let metadataWorksheet = XLSXWorksheet(
            name: sheetNames[1],
            rows: metadataRows(snapshot: snapshot, timestamp: timestamp),
            headerRowIndex: 1,
            autoFilter: true
        )
        let dataDictionaryWorksheet = XLSXWorksheet(
            name: sheetNames[2],
            rows: dataDictionaryRows(snapshot: snapshot),
            headerRowIndex: 1,
            autoFilter: true
        )

        try FileManager.default.createDirectory(at: root.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docProps"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)

        try writeXML(contentTypesXML(worksheetCount: sheetNames.count), to: root.appendingPathComponent("[Content_Types].xml"))
        try writeXML(rootRelationshipsXML(), to: root.appendingPathComponent("_rels/.rels"))
        try writeXML(appPropertiesXML(), to: root.appendingPathComponent("docProps/app.xml"))
        try writeXML(corePropertiesXML(timestamp: timestamp), to: root.appendingPathComponent("docProps/core.xml"))
        try writeXML(workbookXML(sheetNames: sheetNames), to: root.appendingPathComponent("xl/workbook.xml"))
        try writeXML(workbookRelationshipsXML(worksheetCount: sheetNames.count), to: root.appendingPathComponent("xl/_rels/workbook.xml.rels"))
        try writeXML(stylesXML(), to: root.appendingPathComponent("xl/styles.xml"))
        try writeResultsWorksheetXML(
            snapshot: snapshot,
            to: root.appendingPathComponent("xl/worksheets/sheet1.xml")
        )
        try writeXML(
            worksheetXML(metadataWorksheet),
            to: root.appendingPathComponent("xl/worksheets/sheet2.xml")
        )
        try writeXML(
            worksheetXML(dataDictionaryWorksheet),
            to: root.appendingPathComponent("xl/worksheets/sheet3.xml")
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

    static func writeXMLFragment(_ xml: String, to fileHandle: FileHandle) throws {
        guard let data = xml.data(using: .utf8) else {
            throw NSError(
                domain: "WordZMac.XLSXExportService",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "无法生成 Excel XML 数据。"]
            )
        }
        try fileHandle.write(contentsOf: data)
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
