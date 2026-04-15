import Foundation

struct PreparedKeywordSuiteCorpus: Equatable, Sendable {
    let entry: KeywordRequestEntry
    let tokenizedArtifact: StoredTokenizedArtifact
}

struct PreparedKeywordSuiteRequest: Equatable, Sendable {
    let focusCorpora: [PreparedKeywordSuiteCorpus]
    let referenceCorpora: [PreparedKeywordSuiteCorpus]
    let importedReferenceItems: [KeywordReferenceWordListItem]
    let focusLabel: String
    let referenceLabel: String
    let configuration: KeywordSuiteConfiguration
}
