import Foundation

@MainActor
extension WorkspaceLibraryWorkflowService {
    func saveCompareCorpusSet(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        let corpusIDs = compareScopeCorpusIDs(features: features)
        guard !corpusIDs.isEmpty else {
            features.sidebar.setError(wordZText("当前 Compare 没有可保存的语料范围。", "There is no Compare corpus scope to save yet.", mode: .system))
            return
        }

        await saveResultCorpusSet(
            defaultName: wordZText("Compare 语料集", "Compare Corpus Set", mode: .system),
            corpusIDs: corpusIDs,
            metadataFilterState: .empty,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func saveKWICCorpusSet(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let currentCorpus = currentOpenedScopeCorpus(features: features) else {
            features.sidebar.setError(wordZText("当前 KWIC 没有可保存的语料范围。", "There is no KWIC corpus scope to save yet.", mode: .system))
            return
        }

        await saveResultCorpusSet(
            defaultName: currentCorpus.name,
            corpusIDs: [currentCorpus.id],
            metadataFilterState: .empty,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func saveLocatorCorpusSet(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let currentCorpus = currentOpenedScopeCorpus(features: features) else {
            features.sidebar.setError(wordZText("当前 Locator 没有可保存的语料范围。", "There is no Locator corpus scope to save yet.", mode: .system))
            return
        }

        await saveResultCorpusSet(
            defaultName: currentCorpus.name,
            corpusIDs: [currentCorpus.id],
            metadataFilterState: .empty,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    private func saveResultCorpusSet(
        defaultName: String,
        corpusIDs: [String],
        metadataFilterState: CorpusMetadataFilterState,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute?
    ) async {
        guard let repository = repository as? any CorpusSetManagingRepository else {
            features.sidebar.setError(wordZText("当前仓储尚不支持命名语料集。", "The current repository does not support named corpus sets yet.", mode: .system))
            return
        }

        var seenCorpusIDs = Set<String>()
        let resolvedCorpusIDs = corpusIDs.filter { seenCorpusIDs.insert($0).inserted }
        guard !resolvedCorpusIDs.isEmpty else {
            features.sidebar.setError(wordZText("当前没有可保存到语料集的语料。", "There are no corpora available to save into a corpus set.", mode: .system))
            return
        }

        guard let name = await dialogService.promptText(
            title: wordZText("保存语料集", "Save Corpus Set", mode: .system),
            message: wordZText("为当前结果语料范围输入一个名称。", "Enter a name for the current result corpus scope.", mode: .system),
            defaultValue: defaultName,
            confirmTitle: wordZText("保存", "Save", mode: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let savedSet = try await repository.saveCorpusSet(
                name: name,
                corpusIDs: resolvedCorpusIDs,
                metadataFilterState: metadataFilterState
            )
            try await libraryManagementCoordinator.refreshLibraryState(
                into: features.library,
                sidebar: features.sidebar
            )
            await persistenceWorkflow.persistRecentCorpusSetSelection(
                savedSet.id,
                features: features
            )
            features.library.setStatus(
                l10nFormat(
                    "已保存语料集“%@”。",
                    table: "Errors",
                    mode: .system,
                    fallback: "Saved corpus set \"%@\".",
                    savedSet.name
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func compareScopeCorpusIDs(features: WorkspaceFeatureSet) -> [String] {
        var orderedIDs = features.compare.selectedCorpusIDsSnapshot
        switch features.compare.selectedReferenceSelection {
        case .automatic:
            break
        case .corpus(let corpusID):
            if !corpusID.isEmpty {
                orderedIDs.append(corpusID)
            }
        case .corpusSet:
            orderedIDs.append(contentsOf: features.compare.selectedReferenceCorpusSet()?.corpusIDs ?? [])
        }

        let validIDs = Set(features.sidebar.librarySnapshot.corpora.map(\.id))
        return orderedIDs.filter { validIDs.contains($0) }
    }

    private func currentOpenedScopeCorpus(features: WorkspaceFeatureSet) -> LibraryCorpusItem? {
        let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID else { return nil }
        return features.sidebar.librarySnapshot.corpora.first(where: { $0.id == corpusID })
    }
}
