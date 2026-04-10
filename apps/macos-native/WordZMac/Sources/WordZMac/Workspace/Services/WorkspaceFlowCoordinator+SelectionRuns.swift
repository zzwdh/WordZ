import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runCompare(features: WorkspaceFeatureSet) async {
        let allCorporaByID = Dictionary(uniqueKeysWithValues: features.sidebar.librarySnapshot.corpora.map { ($0.id, $0) })
        let selectedCorpora = features.compare.selectedCorpusItems()
        let referenceCorpusSet = features.compare.selectedReferenceCorpusSet()
        let referenceSetCorpora = referenceCorpusSet?.corpusIDs.compactMap { allCorporaByID[$0] } ?? []
        let targetCorpora: [LibraryCorpusItem]
        if let referenceCorpusSet {
            let referenceIDs = Set(referenceCorpusSet.corpusIDs)
            targetCorpora = selectedCorpora.filter { !referenceIDs.contains($0.id) }
        } else {
            targetCorpora = selectedCorpora
        }

        guard targetCorpora.count >= 2 || (referenceCorpusSet != nil && !targetCorpora.isEmpty) else {
            features.sidebar.setError("Compare 至少需要选择 2 条目标语料；如果使用命名参考语料集，至少保留 1 条目标语料。")
            return
        }
        if referenceCorpusSet != nil && referenceSetCorpora.isEmpty {
            features.sidebar.setError("当前命名参考语料集没有可用语料。")
            return
        }

        await performResultRunTask(.compare, selecting: .compare, features: features) {
            let comparisonEntries = try await self.buildComparisonEntries(from: targetCorpora + referenceSetCorpora)
            let result = try await self.repository.runCompare(comparisonEntries: comparisonEntries)
            features.compare.apply(result)
        }
    }

    func runKeyword(features: WorkspaceFeatureSet) async {
        guard let targetCorpus = features.keyword.selectedTargetCorpusItem(),
              let referenceCorpus = features.keyword.selectedReferenceCorpusItem()
        else {
            features.sidebar.setError("关键词分析需要同时选择 Target 和 Reference 语料。")
            return
        }
        guard targetCorpus.id != referenceCorpus.id else {
            features.sidebar.setError("Target 与 Reference 不能是同一条语料。")
            return
        }

        await performResultRunTask(.keyword, selecting: .keyword, features: features) {
            let targetOpened = try await self.repository.openSavedCorpus(corpusId: targetCorpus.id)
            let referenceOpened = try await self.repository.openSavedCorpus(corpusId: referenceCorpus.id)
            let targetEntry = KeywordRequestEntry(
                corpusId: targetCorpus.id,
                corpusName: targetCorpus.name,
                folderName: targetCorpus.folderName,
                content: targetOpened.content
            )
            let referenceEntry = KeywordRequestEntry(
                corpusId: referenceCorpus.id,
                corpusName: referenceCorpus.name,
                folderName: referenceCorpus.folderName,
                content: referenceOpened.content
            )
            features.keyword.recordPendingRunConfiguration()
            let result = try await self.repository.runKeyword(
                targetEntry: targetEntry,
                referenceEntry: referenceEntry,
                options: features.keyword.preprocessingOptions
            )
            features.keyword.apply(result)
        }
    }

    func runChiSquare(features: WorkspaceFeatureSet) async {
        do {
            let inputs = try features.chiSquare.validatedInputs()
            await performResultRunTask(.chiSquare, selecting: .chiSquare, features: features) {
                let result = try await self.repository.runChiSquare(
                    a: inputs.0,
                    b: inputs.1,
                    c: inputs.2,
                    d: inputs.3,
                    yates: features.chiSquare.useYates
                )
                features.chiSquare.apply(result)
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
