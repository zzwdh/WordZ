import Foundation
import WordZShared

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func refreshConcordanceSavedSets(features: WorkspaceFeatureSet) async {
        do {
            let sets = try await repository.listConcordanceSavedSets()
            applyConcordanceSavedSets(sets, features: features)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func deleteConcordanceSavedSet(
        setID: String,
        features: WorkspaceFeatureSet
    ) async {
        let selectedSet = (features.kwic.savedSets + features.locator.savedSets)
            .first { $0.id == setID }
        let setName = selectedSet?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSetName: String
        if let setName, !setName.isEmpty {
            resolvedSetName = setName
        } else {
            resolvedSetName = wordZText("该命中集", "this hit set", mode: .system)
        }
        let confirmed = await dialogService.confirm(
            title: wordZText("删除命中集", "Delete Hit Set", mode: .system),
            message: wordZText(
                "确定要删除「\(resolvedSetName)」吗？此操作无法撤销。",
                "Delete \"\(resolvedSetName)\"? This cannot be undone.",
                mode: .system
            ),
            confirmTitle: wordZText("删除", "Delete", mode: .system),
            preferredRoute: .mainWorkspace
        )
        guard confirmed else { return }

        do {
            try await repository.deleteConcordanceSavedSet(setID: setID)
            let sets = try await repository.listConcordanceSavedSets()
            applyConcordanceSavedSets(sets, features: features)
            features.library.setStatus(wordZText("已删除命中集。", "Deleted hit set.", mode: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func saveConcordanceSavedSet(
        _ set: ConcordanceSavedSet,
        successMessage: String,
        features: WorkspaceFeatureSet
    ) async {
        do {
            _ = try await repository.saveConcordanceSavedSet(set)
            let sets = try await repository.listConcordanceSavedSets()
            applyConcordanceSavedSets(sets, features: features)
            features.library.setStatus(successMessage)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func applyConcordanceSavedSets(_ sets: [ConcordanceSavedSet], features: WorkspaceFeatureSet) {
        features.kwic.applySavedSets(sets.filter { $0.kind == .kwic })
        features.locator.applySavedSets(sets.filter { $0.kind == .locator })
    }

    func selectedConcordanceSavedSet(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) -> ConcordanceSavedSet? {
        switch kind {
        case .kwic:
            return features.kwic.selectedSavedSet
        case .locator:
            return features.locator.selectedSavedSet
        }
    }

    func refinedConcordanceSavedSetRows(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) -> [ConcordanceSavedSetRow] {
        switch kind {
        case .kwic:
            return features.kwic.filteredSelectedSavedSetRows
        case .locator:
            return features.locator.filteredSelectedSavedSetRows
        }
    }

    func currentSavedSetNotesDraft(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) -> String? {
        switch kind {
        case .kwic:
            return features.kwic.savedSetNotesDraft
        case .locator:
            return features.locator.savedSetNotesDraft
        }
    }
}
