import Foundation

@MainActor
extension LibrarySidebarViewModel {
    func syncScene() {
        let availableCorpora = filteredCorpora
        let corpusOptions = availableCorpora.map {
            WorkspaceSidebarCorpusOptionSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: $0.databaseLocationSummary(mode: languageMode)
            )
        }
        let corpusSets = librarySnapshot.corpusSets.map {
            WorkspaceSidebarCorpusSetSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: l10nFormat(
                    "%d 个 DB 语料库",
                    table: "Errors",
                    mode: languageMode,
                    fallback: "%d DB corpora",
                    $0.corpusIDs.count
                ),
                isSelected: $0.id == selectedCorpusSetID
            )
        }
        let targetSummary: WorkspaceSidebarCorpusSlotSceneModel
        if let selectedCorpusSet {
            targetSummary = WorkspaceSidebarCorpusSlotSceneModel(
                title: wordZText("目标 DB 语料集", "Target DB Corpus Set", mode: languageMode),
                corpusID: nil,
                summary: selectedCorpusSet.name,
                detail: l10nFormat(
                    "%d 个 DB 语料库 · DB 语料集",
                    table: "Errors",
                    mode: languageMode,
                    fallback: "%d DB corpora · DB corpus set",
                    selectedCorpusSet.corpusIDs.count
                ),
                isOptional: false
            )
        } else if let target = targetCorpus {
            targetSummary = WorkspaceSidebarCorpusSlotSceneModel(
                title: wordZText("目标 DB", "Target DB Corpus", mode: languageMode),
                corpusID: target.id,
                summary: target.name,
                detail: target.databaseLocationSummary(mode: languageMode),
                isOptional: false
            )
        } else {
            targetSummary = WorkspaceSidebarCorpusSlotSceneModel(
                title: wordZText("目标 DB", "Target DB Corpus", mode: languageMode),
                corpusID: nil,
                summary: wordZText("未选择 DB 语料库", "No target DB corpus selected", mode: languageMode),
                detail: wordZText("请选择要分析的 DB 语料库或 DB 语料集", "Choose the DB corpus or DB corpus set you want to analyze", mode: languageMode),
                isOptional: false
            )
        }
        let referenceSummary = referenceCorpus.map {
            WorkspaceSidebarCorpusSlotSceneModel(
                title: wordZText("参照 DB", "Reference DB Corpus", mode: languageMode),
                corpusID: $0.id,
                summary: $0.name,
                detail: $0.databaseLocationSummary(mode: languageMode),
                isOptional: true
            )
        } ?? workflowReferenceSlotOverride

        let analysisViews = WorkspaceFeatureRegistry.mainTabs.map { tab in
            let descriptor = WorkspaceFeatureRegistry.descriptor(for: tab)
            return WorkspaceSidebarAnalysisSceneItem(
                tab: tab,
                title: descriptor.title(in: languageMode),
                subtitle: descriptor.sidebarSubtitle(in: languageMode),
                isEnabled: isAnalysisEnabled(tab),
                isSelected: activeAnalysisTab == tab
            )
        }

        scene = WorkspaceSidebarSceneModel(
            appName: context.appName,
            versionLabel: context.versionLabel,
            engineStatus: engineStatus,
            engineState: engineState,
            targetCorpus: targetSummary,
            referenceCorpus: referenceSummary,
            selectedCorpusSetSummary: selectedCorpusSet.map {
                wordZText("当前 DB 语料集：", "DB Corpus Set: ", mode: languageMode) + $0.name
            },
            corpusOptions: corpusOptions,
            corpusSets: corpusSets,
            metadataFilterSummary: metadataFilterState.summaryText(in: languageMode),
            analysisViews: analysisViews,
            results: resultsSummary,
            errorMessage: lastErrorMessage
        )
    }

    private var targetCorpus: LibraryCorpusItem? {
        let targetID = workflowTargetCorpusID ?? selectedCorpusID
        guard let targetID else { return nil }
        return filteredCorpora.first(where: { $0.id == targetID })
    }

    private var referenceCorpus: LibraryCorpusItem? {
        guard let workflowReferenceCorpusID,
              workflowReferenceCorpusID != targetCorpus?.id
        else { return nil }
        return filteredCorpora.first(where: { $0.id == workflowReferenceCorpusID })
    }

    private var workflowReferenceSlotOverride: WorkspaceSidebarCorpusSlotSceneModel {
        if let workflowReferenceSummaryOverride,
           !workflowReferenceSummaryOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return WorkspaceSidebarCorpusSlotSceneModel(
                title: wordZText("参照 DB", "Reference DB Corpus", mode: languageMode),
                corpusID: workflowReferenceCorpusID,
                summary: workflowReferenceSummaryOverride,
                detail: workflowReferenceDetailOverride?.isEmpty == false
                    ? workflowReferenceDetailOverride ?? ""
                    : wordZText("显式参考范围已设置", "Explicit reference scope selected", mode: languageMode),
                isOptional: true
            )
        }
        return WorkspaceSidebarCorpusSlotSceneModel(
            title: wordZText("参照 DB", "Reference DB Corpus", mode: languageMode),
            corpusID: nil,
            summary: wordZText("可选", "Optional", mode: languageMode),
            detail: wordZText("可选；用于关键词等 DB 对比分析", "Optional; used for keyword-style DB comparisons", mode: languageMode),
            isOptional: true
        )
    }

    private func isAnalysisEnabled(_ tab: WorkspaceDetailTab) -> Bool {
        guard !isBusy else { return false }

        switch tab {
        case .keyword:
            if let workflowKeywordEnabledOverride {
                return workflowKeywordEnabledOverride && metadataFilterState.isEmpty
            }
            guard let targetID = targetCorpus?.id,
                  let referenceID = referenceCorpus?.id
            else { return false }
            return targetID != referenceID && metadataFilterState.isEmpty
        default:
            return true
        }
    }

    var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }
}
