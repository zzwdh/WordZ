import Foundation

@MainActor
extension LibrarySidebarViewModel {
    func syncScene() {
        let availableCorpora = filteredCorpora
        let corpusOptions = availableCorpora.map {
            WorkspaceSidebarCorpusOptionSceneItem(id: $0.id, title: $0.name, subtitle: $0.folderName)
        }
        let corpusSets = librarySnapshot.corpusSets.map {
            WorkspaceSidebarCorpusSetSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: "\($0.corpusIDs.count) 条语料",
                isSelected: $0.id == selectedCorpusSetID
            )
        }
        let targetSummary = targetCorpus.map {
            WorkspaceSidebarCorpusSlotSceneModel(
                title: wordZText("目标语料", "Target Corpus", mode: languageMode),
                corpusID: $0.id,
                summary: $0.name,
                detail: $0.folderName,
                isOptional: false
            )
        } ?? WorkspaceSidebarCorpusSlotSceneModel(
            title: wordZText("目标语料", "Target Corpus", mode: languageMode),
            corpusID: nil,
            summary: wordZText("未选择语料", "No target corpus selected", mode: languageMode),
            detail: wordZText("请选择要分析的语料", "Choose the corpus you want to analyze", mode: languageMode),
            isOptional: false
        )
        let referenceSummary = referenceCorpus.map {
            WorkspaceSidebarCorpusSlotSceneModel(
                title: wordZText("参照语料", "Reference Corpus", mode: languageMode),
                corpusID: $0.id,
                summary: $0.name,
                detail: $0.folderName,
                isOptional: true
            )
        } ?? WorkspaceSidebarCorpusSlotSceneModel(
            title: wordZText("参照语料", "Reference Corpus", mode: languageMode),
            corpusID: nil,
            summary: wordZText("可选", "Optional", mode: languageMode),
            detail: wordZText("可选；用于关键词等对比分析", "Optional; used for keyword-style comparisons", mode: languageMode),
            isOptional: true
        )

        let analysisViews = WorkspaceDetailTab.mainWorkspaceTabs.map { tab in
            WorkspaceSidebarAnalysisSceneItem(
                tab: tab,
                title: tab.displayTitle(in: languageMode),
                subtitle: navigationSubtitle(for: tab),
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
                wordZText("当前语料集：", "Corpus Set: ", mode: languageMode) + $0.name
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

    private func navigationSubtitle(for tab: WorkspaceDetailTab) -> String {
        switch tab {
        case .stats:
            return wordZText("查看语料规模、类型数与总体分布", "Inspect corpus size, type count, and distribution", mode: languageMode)
        case .word:
            return wordZText("查看词表、频次与标准化频率", "Inspect word lists, counts, and normalized frequency", mode: languageMode)
        case .tokenize:
            return wordZText("生成分词结果并导出清洗后的文本", "Generate tokenized output and cleaned text", mode: languageMode)
        case .topics:
            return wordZText("查看主题簇、代表词与片段分布", "Inspect topic clusters, keywords, and segment spread", mode: languageMode)
        case .compare:
            return wordZText("对比语料之间的显著差异与排序", "Compare corpora and inspect ranked differences", mode: languageMode)
        case .keyword:
            return wordZText("查看目标语料相对参照语料的关键词", "Inspect keywords against the reference corpus", mode: languageMode)
        case .chiSquare:
            return wordZText("运行列联表与卡方显著性检验", "Run contingency tables and chi-square significance checks", mode: languageMode)
        case .ngram:
            return wordZText("查看连续词串及其频率表现", "Inspect phrase sequences and their frequency", mode: languageMode)
        case .kwic:
            return wordZText("查看关键词在上下文中的索引行", "View concordance lines around a keyword", mode: languageMode)
        case .collocate:
            return wordZText("查看节点词的共现词与关联强度", "Inspect co-occurring words and association scores", mode: languageMode)
        case .locator:
            return wordZText("从 KWIC 结果继续追踪原始上下文", "Follow source context from KWIC results", mode: languageMode)
        case .library, .settings:
            return ""
        }
    }

    private func isAnalysisEnabled(_ tab: WorkspaceDetailTab) -> Bool {
        guard !isBusy else { return false }

        switch tab {
        case .keyword:
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
