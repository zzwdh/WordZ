import Foundation

struct AnalysisPresetItem: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let createdAt: String
    let updatedAt: String
    let snapshot: WorkspaceSnapshotSummary

    var activeTab: WorkspaceDetailTab {
        WorkspaceDetailTab.fromSnapshotValue(snapshot.currentTab) ?? .stats
    }

    func summary(in mode: AppLanguageMode) -> String {
        switch activeTab {
        case .stats, .word, .tokenize:
            if !snapshot.searchQuery.isEmpty {
                return wordZText("检索：\(snapshot.searchQuery)", "Query: \(snapshot.searchQuery)", mode: mode)
            }
            return wordZText("全量词项视图", "Full vocabulary view", mode: mode)
        case .topics:
            let topicDetail = wordZText(
                "最小主题：\(snapshot.topicsMinTopicSize)",
                "Min topic size: \(snapshot.topicsMinTopicSize)",
                mode: mode
            )
            if !snapshot.searchQuery.isEmpty {
                return "\(topicDetail) · \(wordZText("检索：\(snapshot.searchQuery)", "Query: \(snapshot.searchQuery)", mode: mode))"
            }
            return topicDetail
        case .compare:
            if snapshot.compareReferenceCorpusID.hasPrefix("set:") {
                return wordZText(
                    "命名参考集 · 目标语料 \(snapshot.compareSelectedCorpusIDs.count) 条",
                    "Named reference set · \(snapshot.compareSelectedCorpusIDs.count) target corpora",
                    mode: mode
                )
            }
            if !snapshot.compareReferenceCorpusID.isEmpty {
                return wordZText(
                    "固定参考语料 · 目标语料 \(snapshot.compareSelectedCorpusIDs.count) 条",
                    "Fixed reference corpus · \(snapshot.compareSelectedCorpusIDs.count) target corpora",
                    mode: mode
                )
            }
            return wordZText(
                "自动参考模式 · 语料 \(snapshot.compareSelectedCorpusIDs.count) 条",
                "Automatic reference mode · \(snapshot.compareSelectedCorpusIDs.count) corpora",
                mode: mode
            )
        case .keyword:
            return wordZText(
                "关键词参数已锁定",
                "Keyword parameters locked",
                mode: mode
            )
        case .chiSquare:
            return wordZText("四格表参数已保存", "Contingency table inputs saved", mode: mode)
        case .ngram:
            let ngramDetail = wordZText("N = \(snapshot.ngramSize)", "N = \(snapshot.ngramSize)", mode: mode)
            if !snapshot.searchQuery.isEmpty {
                return "\(ngramDetail) · \(wordZText("检索：\(snapshot.searchQuery)", "Query: \(snapshot.searchQuery)", mode: mode))"
            }
            return ngramDetail
        case .kwic:
            return wordZText(
                "KWIC：\(snapshot.searchQuery) · L\(snapshot.kwicLeftWindow)/R\(snapshot.kwicRightWindow)",
                "KWIC: \(snapshot.searchQuery) · L\(snapshot.kwicLeftWindow)/R\(snapshot.kwicRightWindow)",
                mode: mode
            )
        case .collocate:
            return wordZText(
                "搭配：\(snapshot.searchQuery) · L\(snapshot.collocateLeftWindow)/R\(snapshot.collocateRightWindow)",
                "Collocate: \(snapshot.searchQuery) · L\(snapshot.collocateLeftWindow)/R\(snapshot.collocateRightWindow)",
                mode: mode
            )
        case .locator:
            return wordZText("基于 KWIC 定位源", "Based on saved KWIC source", mode: mode)
        case .library, .settings:
            return activeTab.displayTitle(in: mode)
        }
    }
}
