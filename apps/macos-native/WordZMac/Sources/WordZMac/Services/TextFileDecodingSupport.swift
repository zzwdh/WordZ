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
        return try readTextDocument(at: url)
    }

    static func readTextDocument(at url: URL) throws -> DecodedTextDocument {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try decode(data: data, sourceName: url.lastPathComponent)
    }

    static func decode(data: Data, sourceName: String) throws -> DecodedTextDocument {
        guard !data.isEmpty else {
            return DecodedTextDocument(text: "", encodingName: "utf-8")
        }

        if let byteOrderMark = detectByteOrderMark(in: data) {
            let trimmedData = data.dropFirst(byteOrderMark.byteCount)
            if let decoded = decodeCandidate(
                data: Data(trimmedData),
                encoding: byteOrderMark.encoding,
                encodingName: byteOrderMark.name
            ) {
                return decoded
            }
        }

        // Prefer UTF-8 when the byte stream cleanly decodes as UTF-8.
        // This avoids short ASCII-heavy legacy corpora being mis-scored as UTF-16 mojibake.
        if let utf8 = decodeCandidate(data: data, encoding: .utf8, encodingName: "utf-8") {
            return utf8
        }

        var bestMatch: (document: DecodedTextDocument, score: Int)?
        for candidate in supportedEncodings {
            guard let decoded = decodeCandidate(
                data: data,
                encoding: candidate.encoding,
                encodingName: candidate.name
            ) else {
                continue
            }
            let score = scoreText(decoded.text)
            if let bestMatch, bestMatch.score >= score {
                continue
            }
            bestMatch = (decoded, score)
        }

        if let bestMatch {
            return bestMatch.document
        }

        throw unsupportedFormatError(fileName: sourceName)
    }

    private static func decodeCandidate(
        data: Data,
        encoding: String.Encoding,
        encodingName: String
    ) -> DecodedTextDocument? {
        guard let string = String(data: data, encoding: encoding) else {
            return nil
        }
        guard isAcceptableText(string) else {
            return nil
        }
        return DecodedTextDocument(text: string, encodingName: encodingName)
    }

    private static func isAcceptableText(_ text: String) -> Bool {
        guard !text.isEmpty else { return true }
        let scalars = Array(text.unicodeScalars)
        let total = Double(max(scalars.count, 1))
        let replacementCount = scalars.filter { $0.value == 0xFFFD }.count
        let nullCount = scalars.filter { $0.value == 0 }.count
        let unexpectedControlCount = scalars.filter {
            CharacterSet.controlCharacters.contains($0) && !allowedControlScalars.contains($0.value)
        }.count
        let likelyTextCount = scalars.filter {
            CharacterSet.letters.contains($0) ||
                CharacterSet.decimalDigits.contains($0) ||
                CharacterSet.whitespacesAndNewlines.contains($0) ||
                CharacterSet.punctuationCharacters.contains($0) ||
                commonTextSymbols.contains($0.value)
        }.count

        let replacementRatio = Double(replacementCount) / total
        let controlRatio = Double(unexpectedControlCount) / total
        let textualRatio = Double(likelyTextCount) / total

        return nullCount == 0 &&
            replacementRatio <= 0.01 &&
            controlRatio <= 0.02 &&
            textualRatio >= 0.85
    }

    private static func scoreText(_ text: String) -> Int {
        let scalars = Array(text.unicodeScalars)
        let total = max(scalars.count, 1)
        let replacementCount = scalars.filter { $0.value == 0xFFFD }.count
        let unexpectedControlCount = scalars.filter {
            CharacterSet.controlCharacters.contains($0) && !allowedControlScalars.contains($0.value)
        }.count
        let letterOrDigitCount = scalars.filter {
            CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
        }.count
        let nonLatinLetterCount = scalars.filter {
            CharacterSet.letters.contains($0) && $0.value > 0x024F
        }.count
        let whitespaceCount = scalars.filter { CharacterSet.whitespacesAndNewlines.contains($0) }.count

        return (letterOrDigitCount * 5) +
            (nonLatinLetterCount * 12) +
            (whitespaceCount * 2) -
            (replacementCount * 250) -
            (unexpectedControlCount * 180) -
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

    private static func unsupportedFormatError(fileName: String) -> NSError {
        NSError(
            domain: "WordZMac.TextFileDecodingSupport",
            code: 415,
            userInfo: [NSLocalizedDescriptionKey: "暂不支持读取该语料文件格式：\(fileName)"]
        )
    }

    private static let supportedEncodings: [(encoding: String.Encoding, name: String)] = [
        (.utf8, "utf-8"),
        (.utf16, "utf-16"),
        (.utf16LittleEndian, "utf-16le"),
        (.utf16BigEndian, "utf-16be"),
        (.utf32, "utf-32"),
        (.utf32LittleEndian, "utf-32le"),
        (.utf32BigEndian, "utf-32be"),
        (.wordZGB18030, "gb18030"),
        (.windowsCP1252, "windows-1252"),
        (.isoLatin1, "iso-8859-1"),
        (.ascii, "ascii")
    ]

    private static let unsupportedBinaryExtensions: Set<String> = [
        "7z", "a", "app", "avi", "bin", "class", "dmg", "doc", "docx", "dylib", "epub",
        "gif", "gz", "heic", "icns", "ico", "jar", "jpeg", "jpg", "key", "m4a", "mov",
        "mp3", "mp4", "numbers", "o", "otf", "pages", "pdf", "pkg", "png", "ppt", "pptx",
        "pyc", "rar", "rtfd", "so", "sqlite", "ttf", "wav", "woff", "woff2", "xls", "xlsx", "zip"
    ]

    private static let allowedControlScalars: Set<UInt32> = [0x09, 0x0A, 0x0D]
    private static let commonTextSymbols: Set<UInt32> = [
        0x0027, 0x002D, 0x2013, 0x2014, 0x2026,
        0x3001, 0x3002, 0xFF0C, 0xFF01, 0xFF1F,
        0x2018, 0x2019, 0x201C, 0x201D,
        0x3008, 0x3009, 0x300A, 0x300B,
        0x3010, 0x3011, 0xFF08, 0xFF09
    ]
}

extension String.Encoding {
    static let wordZGB18030 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
    )
}
