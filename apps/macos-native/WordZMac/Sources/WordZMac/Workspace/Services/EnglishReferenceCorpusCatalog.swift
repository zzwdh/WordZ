import Foundation

package enum EnglishReferenceCorpusKind: String, CaseIterable, Identifiable, Sendable {
    case bnc1994
    case oanc

    package var id: String { rawValue }
}

package struct EnglishReferenceCorpusDescriptor: Identifiable, Equatable, Sendable {
    package let kind: EnglishReferenceCorpusKind
    package let name: String
    package let shortName: String
    package let summary: String
    package let downloadURL: URL
    package let downloadPageURL: URL
    package let packageFileName: String
    package let canBundleWithApp: Bool
    package let licenceNote: String

    package var id: String { kind.rawValue }
}

package enum EnglishReferenceCorpusCatalog {
    package static let bnc1994 = EnglishReferenceCorpusDescriptor(
        kind: .bnc1994,
        name: "BNC1994 English Reference",
        shortName: "BNC1994",
        summary: "British English reference corpus from Oxford.",
        downloadURL: URL(string: "http://ota.oerc.ox.ac.uk/secure/newota/2554.zip")!,
        downloadPageURL: URL(string: "https://llds.ling-phil.ox.ac.uk/llds/xmlui/handle/20.500.14106/2554")!,
        packageFileName: "BNC1994-2554.zip",
        canBundleWithApp: false,
        licenceNote: "BNC1994 is distributed by Oxford under the BNC User Licence. Downloading from Oxford implies acceptance of that licence."
    )

    package static let oanc = EnglishReferenceCorpusDescriptor(
        kind: .oanc,
        name: "OANC American English Reference",
        shortName: "OANC",
        summary: "Open American English reference corpus.",
        downloadURL: URL(string: "https://www.anc.org/OANC/OANC-1.0.1-UTF8.zip")!,
        downloadPageURL: URL(string: "https://anc.org/data/oanc/download/")!,
        packageFileName: "OANC-1.0.1-UTF8.zip",
        canBundleWithApp: false,
        licenceNote: "OANC is provided as an open American English corpus. WordZ downloads the upstream package for each user instead of bundling the 318 MB corpus."
    )

    package static let all: [EnglishReferenceCorpusDescriptor] = [
        bnc1994,
        oanc
    ]

    package static func descriptor(for kind: EnglishReferenceCorpusKind) -> EnglishReferenceCorpusDescriptor {
        switch kind {
        case .bnc1994:
            return bnc1994
        case .oanc:
            return oanc
        }
    }
}
