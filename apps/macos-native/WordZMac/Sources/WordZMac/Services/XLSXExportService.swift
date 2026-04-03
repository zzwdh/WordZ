import Foundation

struct XLSXExportService {
    func write(snapshot: NativeTableExportSnapshot, to path: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            try Self.writeSynchronously(snapshot: snapshot, to: path)
        }.value
    }

    private static func writeSynchronously(snapshot: NativeTableExportSnapshot, to path: String) throws {
        let fileManager = FileManager.default
        let outputURL = URL(fileURLWithPath: path)
        let workingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("wordz-native-xlsx-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workingDirectory) }

        try writeArchiveFiles(snapshot: snapshot, into: workingDirectory)

        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-q", "-r", outputURL.path, "."]
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = Pipe()
        process.standardError = stderrPipe

        let status = try run(process)
        guard status == 0 else {
            let errorText = String(
                data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "WordZMac.XLSXExportService",
                code: Int(status),
                userInfo: [
                    NSLocalizedDescriptionKey: errorText?.isEmpty == false
                        ? errorText!
                        : "Excel 导出失败。"
                ]
            )
        }
    }

    private static func writeArchiveFiles(snapshot: NativeTableExportSnapshot, into root: URL) throws {
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

    private static func writeXML(_ xml: String, to url: URL) throws {
        try xml.data(using: .utf8)?.write(to: url, options: .atomic) ?? {
            throw NSError(
                domain: "WordZMac.XLSXExportService",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "无法生成 Excel XML 数据。"]
            )
        }()
    }

    private static func run(_ process: Process) throws -> Int32 {
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }
        try process.run()
        group.wait()
        return process.terminationStatus
    }

    private static func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        </Types>
        """
    }

    private static func rootRelationshipsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """
    }

    private static func appPropertiesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
          <Application>WordZ</Application>
        </Properties>
        """
    }

    private static func corePropertiesXML(timestamp: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:creator>WordZ</dc:creator>
          <cp:lastModifiedBy>WordZ</cp:lastModifiedBy>
          <dcterms:created xsi:type="dcterms:W3CDTF">\(timestamp)</dcterms:created>
          <dcterms:modified xsi:type="dcterms:W3CDTF">\(timestamp)</dcterms:modified>
        </cp:coreProperties>
        """
    }

    private static func workbookXML(sheetName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="\(xmlEscaped(sheetName))" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """
    }

    private static func workbookRelationshipsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
    }

    private static func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="2">
            <font>
              <sz val="11"/>
              <name val="Helvetica Neue"/>
            </font>
            <font>
              <b/>
              <sz val="11"/>
              <name val="Helvetica Neue"/>
            </font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1">
            <border><left/><right/><top/><bottom/><diagonal/></border>
          </borders>
          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>
          <cellXfs count="2">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
          </cellXfs>
          <cellStyles count="1">
            <cellStyle name="Normal" xfId="0" builtinId="0"/>
          </cellStyles>
        </styleSheet>
        """
    }

    private static func worksheetRows(snapshot: NativeTableExportSnapshot) -> [[String]] {
        var rows = snapshot.metadataLines.map { [$0] }
        if !snapshot.metadataLines.isEmpty {
            rows.append([])
        }
        rows.append(snapshot.table.csvHeaderRow())
        rows.append(contentsOf: snapshot.table.csvRows(from: snapshot.rows))
        return rows
    }

    private static func worksheetXML(rows: [[String]], headerRowIndex: Int) -> String {
        let allRows = rows.isEmpty ? [[]] : rows
        let xmlRows = allRows.enumerated().map { rowIndex, values in
            let styleIndex = rowIndex + 1 == headerRowIndex ? 1 : 0
            let cells = values.enumerated().map { columnIndex, value in
                let cellReference = "\(columnName(for: columnIndex + 1))\(rowIndex + 1)"
                return """
                <c r="\(cellReference)" t="inlineStr" s="\(styleIndex)"><is>\(inlineStringTextNode(value))</is></c>
                """
            }.joined()
            return "<row r=\"\(rowIndex + 1)\">\(cells)</row>"
        }.joined()

        let maxColumns = max(allRows.map(\.count).max() ?? 0, 1)
        let lastColumn = columnName(for: maxColumns)
        let dimension = "A1:\(lastColumn)\(max(allRows.count, 1))"
        let columns = (0..<maxColumns).map { index in
            let sampleWidth = allRows
                .prefix(256)
                .compactMap { row -> Int? in
                    guard index < row.count else { return nil }
                    return row[index].count
                }
                .max() ?? 0
            let width = min(max(sampleWidth + 4, 10), 48)
            return "<col min=\"\(index + 1)\" max=\"\(index + 1)\" width=\"\(width)\" customWidth=\"1\"/>"
        }.joined()
        let freezePane = """
          <pane ySplit="\(headerRowIndex)" topLeftCell="A\(headerRowIndex + 1)" activePane="bottomLeft" state="frozen"/>
          <selection pane="bottomLeft"/>
        """
        let autoFilter = headerRowIndex <= allRows.count
            ? "<autoFilter ref=\"A\(headerRowIndex):\(lastColumn)\(headerRowIndex)\"/>"
            : ""

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <dimension ref="\(dimension)"/>
          <sheetViews>
            <sheetView workbookViewId="0">
        """ + freezePane + """
            </sheetView>
          </sheetViews>
          <sheetFormatPr defaultRowHeight="18"/>
          <cols>\(columns)</cols>
          <sheetData>\(xmlRows)</sheetData>
          \(autoFilter)
        </worksheet>
        """
    }

    private static func columnName(for index: Int) -> String {
        var index = index
        var result = ""
        while index > 0 {
            let remainder = (index - 1) % 26
            result = String(UnicodeScalar(65 + remainder)!) + result
            index = (index - 1) / 26
        }
        return result.isEmpty ? "A" : result
    }

    private static func inlineStringTextNode(_ value: String) -> String {
        let escaped = xmlEscaped(value)
        if escaped.hasPrefix(" ") || escaped.hasSuffix(" ") || escaped.contains("\n") {
            return "<t xml:space=\"preserve\">\(escaped)</t>"
        }
        return "<t>\(escaped)</t>"
    }

    private static func xmlEscaped(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }

    private static func sanitizedSheetName(_ suggestedBaseName: String) -> String {
        let trimmed = suggestedBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Results" : trimmed
        let invalid = CharacterSet(charactersIn: "[]:*?/\\\\")
        let cleaned = fallback.unicodeScalars.map { invalid.contains($0) ? "_" : Character($0) }
        return String(cleaned.prefix(31))
    }

    private static func iso8601Timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
