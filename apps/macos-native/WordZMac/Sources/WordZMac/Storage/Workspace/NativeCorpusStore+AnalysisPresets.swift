import Foundation

extension NativeCorpusStore: AnalysisPresetManagingStorage {
    func listAnalysisPresets() throws -> [AnalysisPresetItem] {
        try ensureInitialized()
        return try loadAnalysisPresets()
            .sorted { $0.updatedAt > $1.updatedAt }
            .map(\.item)
    }

    func saveAnalysisPreset(name: String, draft: WorkspaceStateDraft) throws -> AnalysisPresetItem {
        try ensureInitialized()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw missingItemError("分析预设名称不能为空。")
        }

        var presets = try loadAnalysisPresets()
        let now = timestamp()
        let snapshot = NativePersistedWorkspaceSnapshot(draft: draft)

        if let existingIndex = presets.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            presets[existingIndex].name = trimmedName
            presets[existingIndex].updatedAt = now
            presets[existingIndex].workspaceSnapshot = snapshot
            try saveAnalysisPresets(presets)
            return presets[existingIndex].item
        }

        let created = NativeAnalysisPresetRecord(
            id: UUID().uuidString,
            name: trimmedName,
            createdAt: now,
            updatedAt: now,
            workspaceSnapshot: snapshot
        )
        presets.append(created)
        try saveAnalysisPresets(presets)
        return created.item
    }

    func deleteAnalysisPreset(presetID: String) throws {
        try ensureInitialized()

        var presets = try loadAnalysisPresets()
        guard presets.contains(where: { $0.id == presetID }) else {
            throw missingItemError("未找到要删除的分析预设。")
        }
        presets.removeAll { $0.id == presetID }
        try saveAnalysisPresets(presets)
    }
}
