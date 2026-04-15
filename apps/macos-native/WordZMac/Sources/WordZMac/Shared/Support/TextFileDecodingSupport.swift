import Foundation

struct DecodedTextDocument: Equatable {
    let text: String
    let encodingName: String
}

enum TextFileDecodingSupport {
    static func readImportedTextDocument(at url: URL) throws -> DecodedTextDocument {
        let pathExtension = url.pathExtension.lowercased()
        if unsupportedBinaryExtensions.contains(pathExtension) {
            throw unsupportedFormatError(fileName: url.lastPathComponent)
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try decodeImported(data: data, sourceName: url.lastPathComponent)
    }

    static func readTextDocument(at url: URL) throws -> DecodedTextDocument {
        if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           fileSize >= directDecodeFileSizeThreshold,
           let directDocument = try readDirectTextDocumentIfPossible(at: url) {
            return directDocument
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try decode(data: data, sourceName: url.lastPathComponent)
    }

    private static func readDirectTextDocumentIfPossible(at url: URL) throws -> DecodedTextDocument? {
        let probeData = try readProbeData(at: url, byteCount: decodingProbeByteCount)
        guard !probeData.isEmpty else {
            return DecodedTextDocument(text: "", encodingName: "utf-8")
        }

        if let byteOrderMark = detectByteOrderMark(in: probeData) {
            return try decodeDirectDocument(
                at: url,
                encoding: byteOrderMark.encoding,
                encodingName: byteOrderMark.name
            )
        }

        if isLikelyUTF8(probeData),
           let utf8Document = try decodeDirectDocument(at: url, encoding: .utf8, encodingName: "utf-8") {
            return utf8Document
        }

        if let preferredUnicode = preferredUnicodeEncoding(for: probeData) {
            return try decodeDirectDocument(
                at: url,
                encoding: preferredUnicode.encoding,
                encodingName: preferredUnicode.name
            )
        }

        return nil
    }

    private static func readProbeData(at url: URL, byteCount: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: byteCount) ?? Data()
    }

    private static func decodeDirectDocument(
        at url: URL,
        encoding: String.Encoding,
        encodingName: String
    ) throws -> DecodedTextDocument? {
        if streamedDirectEncodings.contains(encoding) {
            return try decodeDirectStreamedDocument(
                at: url,
                encoding: encoding,
                encodingName: encodingName
            )
        }

        guard let string = try? String(contentsOf: url, encoding: encoding) else {
            return nil
        }
        let sanitized = sanitizeDecodedString(string)
        let metrics = analyzeText(sanitized)
        guard isAcceptableText(metrics) else {
            return nil
        }
        return DecodedTextDocument(text: sanitized, encodingName: encodingName)
    }

    private static func decodeDirectStreamedDocument(
        at url: URL,
        encoding: String.Encoding,
        encodingName: String
    ) throws -> DecodedTextDocument? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var pendingBytes = Data()
        var decodedText = ""

        while let chunk = try handle.read(upToCount: directReadChunkByteCount), !chunk.isEmpty {
            pendingBytes.append(chunk)

            guard let step = streamedDecodeStep(
                for: pendingBytes,
                encoding: encoding,
                maxCarryByteCount: streamedEncodingMaxCarryByteCount
            ) else {
                return nil
            }

            decodedText.append(step.decodedText)
            pendingBytes = step.pendingBytes
        }

        if !pendingBytes.isEmpty {
            guard let tail = String(data: pendingBytes, encoding: encoding) else {
                return nil
            }
            decodedText.append(tail)
        }

        let sanitized = sanitizeDecodedString(decodedText)
        let metrics = analyzeText(sanitized)
        guard isAcceptableText(metrics) else {
            return nil
        }
        return DecodedTextDocument(text: sanitized, encodingName: encodingName)
    }

    static func decode(data: Data, sourceName: String) throws -> DecodedTextDocument {
        guard !data.isEmpty else {
            return DecodedTextDocument(text: "", encodingName: "utf-8")
        }

        if let byteOrderMark = detectByteOrderMark(in: data) {
            let trimmedData = data.dropFirst(byteOrderMark.byteCount)
            if let decoded = evaluateDecodedText(
                data: Data(trimmedData),
                encoding: byteOrderMark.encoding,
                encodingName: byteOrderMark.name
            ) {
                return decoded.document
            }
        }

        // Prefer UTF-8 when the byte stream cleanly decodes as UTF-8.
        // This avoids short ASCII-heavy legacy corpora being mis-scored as UTF-16 mojibake.
        if let utf8 = evaluateDecodedText(data: data, encoding: .utf8, encodingName: "utf-8") {
            return utf8.document
        }

        if let preferredUnicode = preferredUnicodeEncoding(for: data),
           let decoded = evaluateDecodedText(
               data: data,
               encoding: preferredUnicode.encoding,
               encodingName: preferredUnicode.name
           ) {
            return decoded.document
        }

        var bestMatch: DecodedTextEvaluation?
        for candidate in candidateEncodings(for: data) {
            guard let decoded = evaluateDecodedText(
                data: data,
                encoding: candidate.encoding,
                encodingName: candidate.name
            ) else {
                continue
            }
            if let bestMatch, bestMatch.score >= decoded.score {
                continue
            }
            bestMatch = decoded
        }

        if let bestMatch {
            return bestMatch.document
        }

        throw unsupportedFormatError(fileName: sourceName)
    }

    private static func decodeImported(data: Data, sourceName: String) throws -> DecodedTextDocument {
        guard !data.isEmpty else {
            return DecodedTextDocument(text: "", encodingName: "utf-8")
        }

        if let byteOrderMark = detectByteOrderMark(in: data),
           let decoded = decodeImportedText(
               data: data.dropFirst(byteOrderMark.byteCount),
               encoding: byteOrderMark.encoding,
               encodingName: byteOrderMark.name,
               preserveLeadingBOM: true
           ) {
            return decoded
        }

        if let utf8 = decodeImportedText(
            data: data[...],
            encoding: .utf8,
            encodingName: "utf-8",
            preserveLeadingBOM: false
        ) {
            return utf8
        }

        if let preferredUnicode = preferredUnicodeEncoding(for: data),
           let decoded = decodeImportedText(
               data: data[...],
               encoding: preferredUnicode.encoding,
               encodingName: preferredUnicode.name,
               preserveLeadingBOM: false
           ) {
            return decoded
        }

        var bestMatch: DecodedTextEvaluation?
        for candidate in candidateEncodings(for: data) {
            guard let decoded = decodeImportedText(
                data: data[...],
                encoding: candidate.encoding,
                encodingName: candidate.name,
                preserveLeadingBOM: false
            ) else {
                continue
            }

            let metrics = analyzeText(decoded.text)
            let evaluation = DecodedTextEvaluation(document: decoded, score: scoreText(metrics))
            if let bestMatch, bestMatch.score >= evaluation.score {
                continue
            }
            bestMatch = evaluation
        }

        if let bestMatch {
            return bestMatch.document
        }

        throw unsupportedFormatError(fileName: sourceName)
    }

    private static func preferredUnicodeEncoding(for data: Data) -> (encoding: String.Encoding, name: String)? {
        let profile = BytePatternProfile(bytes: Array(data.prefix(decodingProbeByteCount)))
        if profile.looksLikeUTF32LittleEndian {
            return (.utf32LittleEndian, "utf-32le")
        }
        if profile.looksLikeUTF32BigEndian {
            return (.utf32BigEndian, "utf-32be")
        }
        if profile.looksLikeUTF16LittleEndian {
            return (.utf16LittleEndian, "utf-16le")
        }
        if profile.looksLikeUTF16BigEndian {
            return (.utf16BigEndian, "utf-16be")
        }
        return nil
    }

    private static func evaluateDecodedText(
        data: Data,
        encoding: String.Encoding,
        encodingName: String
    ) -> DecodedTextEvaluation? {
        guard let string = String(data: data, encoding: encoding) else {
            return nil
        }
        let metrics = analyzeText(string)
        guard isAcceptableText(metrics) else {
            return nil
        }
        return DecodedTextEvaluation(
            document: DecodedTextDocument(text: string, encodingName: encodingName),
            score: scoreText(metrics)
        )
    }

    private static func decodeImportedText(
        data: Data.SubSequence,
        encoding: String.Encoding,
        encodingName: String,
        preserveLeadingBOM: Bool
    ) -> DecodedTextDocument? {
        guard let decoded = String(data: data, encoding: encoding) else {
            return nil
        }

        let text = preserveLeadingBOM ? "\u{FEFF}" + decoded : decoded
        let metrics = analyzeText(text)
        guard isAcceptableImportedText(metrics) else {
            return nil
        }
        return DecodedTextDocument(text: text, encodingName: encodingName)
    }

    private static func candidateEncodings(for data: Data) -> [(encoding: String.Encoding, name: String)] {
        let profile = BytePatternProfile(bytes: Array(data.prefix(decodingProbeByteCount)))

        if profile.looksLikeUTF32LittleEndian {
            return utf32LittleEndianPriorityEncodings
        }
        if profile.looksLikeUTF32BigEndian {
            return utf32BigEndianPriorityEncodings
        }
        if profile.looksLikeUTF16LittleEndian {
            return utf16LittleEndianPriorityEncodings
        }
        if profile.looksLikeUTF16BigEndian {
            return utf16BigEndianPriorityEncodings
        }
        if profile.hasNoNullBytes {
            return legacyAndSingleByteEncodings
        }
        if profile.hasHeavyNullBytes {
            return unicodePriorityEncodings
        }
        return broadFallbackEncodings
    }

    private static func isLikelyUTF8(_ data: Data) -> Bool {
        String(data: data, encoding: .utf8) != nil
    }

    private static func sanitizeDecodedString(_ string: String) -> String {
        if string.unicodeScalars.first?.value == 0xFEFF {
            return String(string.unicodeScalars.dropFirst())
        }
        return string
    }

    private static func analyzeText(_ text: String) -> TextScalarMetrics {
        var metrics = TextScalarMetrics()
        for scalar in text.unicodeScalars {
            metrics.totalCount += 1
            if scalar.value == 0xFFFD {
                metrics.replacementCount += 1
            }
            if scalar.value == 0 {
                metrics.nullCount += 1
            }
            if CharacterSet.controlCharacters.contains(scalar) && !allowedControlScalars.contains(scalar.value) {
                metrics.unexpectedControlCount += 1
                if importSafeControlScalars.contains(scalar.value) {
                    metrics.cleanableControlCount += 1
                }
            }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                metrics.whitespaceCount += 1
            }
            if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
                metrics.letterOrDigitCount += 1
            }
            if CharacterSet.letters.contains(scalar) && scalar.value > 0x024F {
                metrics.nonLatinLetterCount += 1
            }
            if CharacterSet.letters.contains(scalar) ||
                CharacterSet.decimalDigits.contains(scalar) ||
                CharacterSet.whitespacesAndNewlines.contains(scalar) ||
                CharacterSet.punctuationCharacters.contains(scalar) ||
                commonTextSymbols.contains(scalar.value) {
                metrics.likelyTextCount += 1
            }
        }
        return metrics
    }

    private static func isAcceptableText(_ metrics: TextScalarMetrics) -> Bool {
        let total = Double(max(metrics.totalCount, 1))
        let replacementRatio = Double(metrics.replacementCount) / total
        let controlRatio = Double(metrics.unexpectedControlCount) / total
        let textualRatio = Double(metrics.likelyTextCount) / total

        return metrics.nullCount == 0 &&
            replacementRatio <= 0.01 &&
            controlRatio <= 0.02 &&
            textualRatio >= 0.85
    }

    private static func isAcceptableImportedText(_ metrics: TextScalarMetrics) -> Bool {
        let total = Double(max(metrics.totalCount, 1))
        let replacementRatio = Double(metrics.replacementCount) / total
        let controlRatio = Double(max(0, metrics.unexpectedControlCount - metrics.cleanableControlCount)) / total
        let nullRatio = Double(metrics.nullCount) / total
        let textualRatio = Double(metrics.likelyTextCount) / total

        return replacementRatio <= 0.01 &&
            controlRatio <= 0.03 &&
            nullRatio <= 0.06 &&
            textualRatio >= 0.7
    }

    private static func scoreText(_ metrics: TextScalarMetrics) -> Int {
        let total = max(metrics.totalCount, 1)
        return (metrics.letterOrDigitCount * 5) +
            (metrics.nonLatinLetterCount * 12) +
            (metrics.whitespaceCount * 2) -
            (metrics.replacementCount * 250) -
            (metrics.unexpectedControlCount * 180) -
            (total / 10)
    }

    private static func detectByteOrderMark(in data: Data) -> (encoding: String.Encoding, name: String, byteCount: Int)? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return (.utf8, "utf-8", 3)
        }
        if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            return (.utf32LittleEndian, "utf-32le", 4)
        }
        if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            return (.utf32BigEndian, "utf-32be", 4)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return (.utf16LittleEndian, "utf-16le", 2)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return (.utf16BigEndian, "utf-16be", 2)
        }
        return nil
    }

    private static func streamedDecodeStep(
        for data: Data,
        encoding: String.Encoding,
        maxCarryByteCount: Int
    ) -> (decodedText: String, pendingBytes: Data)? {
        guard !data.isEmpty else {
            return ("", Data())
        }

        let resolvedMaxCarry = min(maxCarryByteCount, data.count)
        for carryByteCount in 0...resolvedMaxCarry {
            let prefixCount = data.count - carryByteCount
            if prefixCount == 0 {
                continue
            }

            let prefix = data.prefix(prefixCount)
            guard let decodedText = String(data: prefix, encoding: encoding) else {
                continue
            }

            let pendingBytes = carryByteCount == 0 ? Data() : Data(data.suffix(carryByteCount))
            return (decodedText, pendingBytes)
        }

        if data.count <= resolvedMaxCarry {
            return ("", data)
        }

        return nil
    }

    private static func unsupportedFormatError(fileName: String) -> NSError {
        NSError(
            domain: "WordZMac.TextFileDecodingSupport",
            code: 415,
            userInfo: [NSLocalizedDescriptionKey: "暂不支持读取该语料文件格式：\(fileName)"]
        )
    }

    private static let unicodeEncodings: [(encoding: String.Encoding, name: String)] = [
        (.utf16, "utf-16"),
        (.utf16LittleEndian, "utf-16le"),
        (.utf16BigEndian, "utf-16be"),
        (.utf32, "utf-32"),
        (.utf32LittleEndian, "utf-32le"),
        (.utf32BigEndian, "utf-32be")
    ]

    private static let unicodePriorityEncodings: [(encoding: String.Encoding, name: String)] =
        unicodeEncodings + legacyAndSingleByteEncodings

    private static let utf16LittleEndianPriorityEncodings: [(encoding: String.Encoding, name: String)] = [
        (.utf16LittleEndian, "utf-16le"),
        (.utf32LittleEndian, "utf-32le")
    ] + legacyAndSingleByteEncodings

    private static let utf16BigEndianPriorityEncodings: [(encoding: String.Encoding, name: String)] = [
        (.utf16BigEndian, "utf-16be"),
        (.utf32BigEndian, "utf-32be")
    ] + legacyAndSingleByteEncodings

    private static let utf32LittleEndianPriorityEncodings: [(encoding: String.Encoding, name: String)] = [
        (.utf32LittleEndian, "utf-32le"),
        (.utf16LittleEndian, "utf-16le")
    ] + legacyAndSingleByteEncodings

    private static let utf32BigEndianPriorityEncodings: [(encoding: String.Encoding, name: String)] = [
        (.utf32BigEndian, "utf-32be"),
        (.utf16BigEndian, "utf-16be")
    ] + legacyAndSingleByteEncodings

    private static let legacyAndSingleByteEncodings: [(encoding: String.Encoding, name: String)] = [
        (.wordZGB18030, "gb18030"),
        (.windowsCP1252, "windows-1252"),
        (.isoLatin1, "iso-8859-1"),
        (.ascii, "ascii")
    ]

    private static let broadFallbackEncodings: [(encoding: String.Encoding, name: String)] =
        legacyAndSingleByteEncodings + unicodeEncodings

    private static let decodingProbeByteCount = 4096
    private static let directDecodeFileSizeThreshold = 512 * 1024
    private static let directReadChunkByteCount = 64 * 1024
    private static let streamedEncodingMaxCarryByteCount = 8
    private static let streamedDirectEncodings: Set<String.Encoding> = [
        .utf8,
        .utf16LittleEndian,
        .utf16BigEndian,
        .utf32LittleEndian,
        .utf32BigEndian
    ]

    private static let unsupportedBinaryExtensions: Set<String> = [
        "7z", "a", "app", "avi", "bin", "class", "dmg", "doc", "docx", "dylib", "epub",
        "gif", "gz", "heic", "icns", "ico", "jar", "jpeg", "jpg", "key", "m4a", "mov",
        "mp3", "mp4", "numbers", "o", "otf", "pages", "pdf", "pkg", "png", "ppt", "pptx",
        "pyc", "rar", "rtfd", "so", "sqlite", "ttf", "wav", "woff", "woff2", "xls", "xlsx", "zip"
    ]

    private static let allowedControlScalars: Set<UInt32> = [0x09, 0x0A, 0x0D]
    private static let importSafeControlScalars: Set<UInt32> = [
        0x0000, 0x000C, 0xFEFF, 0x200B, 0x200C, 0x200D, 0x2060
    ]
    private static let commonTextSymbols: Set<UInt32> = [
        0x0027, 0x002D, 0x2013, 0x2014, 0x2026,
        0x3001, 0x3002, 0xFF0C, 0xFF01, 0xFF1F,
        0x2018, 0x2019, 0x201C, 0x201D,
        0x3008, 0x3009, 0x300A, 0x300B,
        0x3010, 0x3011, 0xFF08, 0xFF09
    ]
}

private struct DecodedTextEvaluation {
    let document: DecodedTextDocument
    let score: Int
}

private struct TextScalarMetrics {
    var totalCount = 0
    var replacementCount = 0
    var nullCount = 0
    var unexpectedControlCount = 0
    var cleanableControlCount = 0
    var likelyTextCount = 0
    var letterOrDigitCount = 0
    var nonLatinLetterCount = 0
    var whitespaceCount = 0
}

private struct BytePatternProfile {
    let bytes: [UInt8]

    var hasNoNullBytes: Bool {
        !bytes.contains(0)
    }

    var hasHeavyNullBytes: Bool {
        guard !bytes.isEmpty else { return false }
        return Double(nullCount) / Double(bytes.count) >= 0.20
    }

    var looksLikeUTF16LittleEndian: Bool {
        oddNullRatio >= 0.25 && evenNullRatio <= 0.05
    }

    var looksLikeUTF16BigEndian: Bool {
        evenNullRatio >= 0.25 && oddNullRatio <= 0.05
    }

    var looksLikeUTF32LittleEndian: Bool {
        trailingThreeNullQuadRatio >= 0.45
    }

    var looksLikeUTF32BigEndian: Bool {
        leadingThreeNullQuadRatio >= 0.45
    }

    private var nullCount: Int {
        bytes.lazy.filter { $0 == 0 }.count
    }

    private var evenNullRatio: Double {
        positionNullRatio(startIndex: 0, stride: 2)
    }

    private var oddNullRatio: Double {
        positionNullRatio(startIndex: 1, stride: 2)
    }

    private var leadingThreeNullQuadRatio: Double {
        quadPatternRatio { quad in quad[0] == 0 && quad[1] == 0 && quad[2] == 0 && quad[3] != 0 }
    }

    private var trailingThreeNullQuadRatio: Double {
        quadPatternRatio { quad in quad[0] != 0 && quad[1] == 0 && quad[2] == 0 && quad[3] == 0 }
    }

    private func positionNullRatio(startIndex: Int, stride: Int) -> Double {
        var total = 0
        var nulls = 0
        var index = startIndex
        while index < bytes.count {
            total += 1
            if bytes[index] == 0 {
                nulls += 1
            }
            index += stride
        }
        guard total > 0 else { return 0 }
        return Double(nulls) / Double(total)
    }

    private func quadPatternRatio(_ predicate: ([UInt8]) -> Bool) -> Double {
        guard bytes.count >= 4 else { return 0 }
        let quadCount = bytes.count / 4
        guard quadCount > 0 else { return 0 }
        var matches = 0
        for quadIndex in 0..<quadCount {
            let start = quadIndex * 4
            let quad = Array(bytes[start..<(start + 4)])
            if predicate(quad) {
                matches += 1
            }
        }
        return Double(matches) / Double(quadCount)
    }
}

extension String.Encoding {
    static let wordZGB18030 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
    )
}
