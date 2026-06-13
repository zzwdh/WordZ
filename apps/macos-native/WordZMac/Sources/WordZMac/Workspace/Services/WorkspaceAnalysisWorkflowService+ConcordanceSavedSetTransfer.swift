import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func importConcordanceSavedSetsJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let path = await dialogService.chooseOpenPath(
            title: wordZText("导入命中集文件", "Import Hit Set File", mode: .system),
            message: wordZText("选择通过 KWIC 或定位器导出的命中集文件。", "Choose a hit set file exported from KWIC or Locator.", mode: .system),
            allowedExtensions: ["json"],
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let existingSets = try await repository.listConcordanceSavedSets()
            let importedSets = try ConcordanceSavedSetTransferSupport.importedSets(from: data, existingSets: existingSets)
            guard !importedSets.isEmpty else {
                features.sidebar.setError(wordZText("文件中没有可导入的命中集。", "There are no hit sets to import from this file.", mode: .system))
                return
            }
            for set in importedSets {
                _ = try await repository.saveConcordanceSavedSet(set)
            }
            let refreshedSets = try await repository.listConcordanceSavedSets()
            applyConcordanceSavedSets(refreshedSets, features: features)
            features.library.setStatus(
                String(
                    format: wordZText(
                        "已导入 %d 份命中集。",
                        "Imported %d hit sets.",
                        mode: .system
                    ),
                    importedSets.count
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportSelectedConcordanceSavedSetJSON(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        let selectedSet: ConcordanceSavedSet?
        switch kind {
        case .kwic:
            selectedSet = features.kwic.selectedSavedSet
        case .locator:
            selectedSet = features.locator.selectedSavedSet
        }
        guard let selectedSet else {
            features.sidebar.setError(wordZText("请先选择一份已保存命中集。", "Choose a saved hit set first.", mode: .system))
            return
        }

        let suggestedName = "\(slug(selectedSet.name, fallback: kind.rawValue))-hit-set.json"
        guard let path = await dialogService.chooseSavePath(
            title: wordZText("导出命中集", "Export Hit Set", mode: .system),
            suggestedName: suggestedName,
            allowedExtension: "json",
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let data = try ConcordanceSavedSetTransferSupport.exportData(sets: [selectedSet])
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            features.library.setStatus(
                l10nFormat(
                    "已导出命中集“%@”。",
                    table: "Errors",
                    mode: .system,
                    fallback: "Exported hit set \"%@\".",
                    selectedSet.name
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
