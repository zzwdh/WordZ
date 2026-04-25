import Foundation

protocol AnalysisPresetManagingStorage: AnyObject {
    func listAnalysisPresets() throws -> [AnalysisPresetItem]
    func saveAnalysisPreset(name: String, draft: WorkspaceStateDraft) throws -> AnalysisPresetItem
    func deleteAnalysisPreset(presetID: String) throws
}

struct NativeAnalysisPresetRecord: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    let createdAt: String
    var updatedAt: String
    var workspaceSnapshot: NativePersistedWorkspaceSnapshot

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case updatedAt
        case workspaceSnapshot
    }

    var item: AnalysisPresetItem {
        AnalysisPresetItem(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            snapshot: workspaceSnapshot.workspaceSnapshot
        )
    }
}

protocol KeywordSavedListManagingStorage: AnyObject {
    func listKeywordSavedLists() throws -> [KeywordSavedList]
    func saveKeywordSavedList(_ list: KeywordSavedList) throws -> KeywordSavedList
    func deleteKeywordSavedList(listID: String) throws
}

protocol ConcordanceSavedSetManagingStorage: AnyObject {
    func listConcordanceSavedSets() throws -> [ConcordanceSavedSet]
    func saveConcordanceSavedSet(_ set: ConcordanceSavedSet) throws -> ConcordanceSavedSet
    func deleteConcordanceSavedSet(setID: String) throws
}

protocol EvidenceItemManagingStorage: AnyObject {
    func listEvidenceItems() throws -> [EvidenceItem]
    func saveEvidenceItem(_ item: EvidenceItem) throws -> EvidenceItem
    func deleteEvidenceItem(itemID: String) throws
    func replaceEvidenceItems(_ items: [EvidenceItem]) throws
}

protocol SentimentReviewSampleManagingStorage: AnyObject {
    func listSentimentReviewSamples() throws -> [SentimentReviewSample]
    func saveSentimentReviewSample(_ sample: SentimentReviewSample) throws -> SentimentReviewSample
    func deleteSentimentReviewSample(sampleID: String) throws
    func replaceSentimentReviewSamples(_ samples: [SentimentReviewSample]) throws
}
