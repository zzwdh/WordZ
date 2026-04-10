import Foundation

@MainActor
protocol AnalysisPresetManagingRepository: AnyObject {
    func listAnalysisPresets() async throws -> [AnalysisPresetItem]
    func saveAnalysisPreset(name: String, draft: WorkspaceStateDraft) async throws -> AnalysisPresetItem
    func deleteAnalysisPreset(presetID: String) async throws
}
