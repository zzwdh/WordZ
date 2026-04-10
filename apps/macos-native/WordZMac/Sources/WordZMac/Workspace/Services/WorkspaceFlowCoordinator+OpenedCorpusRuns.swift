import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runStats(features: WorkspaceFeatureSet) async {
        await performOpenedCorpusRunTask(.stats, selecting: .stats, features: features) { corpus in
            let result = try await self.repository.runStats(text: corpus.content)
            features.stats.apply(result)
            features.word.apply(result, rebuildSceneAfterApply: false)
        }
    }

    func runWord(features: WorkspaceFeatureSet) async {
        await performOpenedCorpusRunTask(.word, selecting: .word, features: features) { corpus in
            let result = try await self.repository.runStats(text: corpus.content)
            features.stats.apply(result, rebuildSceneAfterApply: false)
            features.word.apply(result)
        }
    }

    func runTokenize(features: WorkspaceFeatureSet) async {
        await performOpenedCorpusRunTask(.tokenize, selecting: .tokenize, features: features) { corpus in
            let result = try await self.repository.runTokenize(text: corpus.content)
            features.tokenize.apply(result)
        }
    }

    func runKWIC(features: WorkspaceFeatureSet) async {
        let keyword = features.kwic.normalizedKeyword
        guard !keyword.isEmpty else {
            features.sidebar.setError("请输入 KWIC 关键词。")
            return
        }

        await performOpenedCorpusRunTask(.kwic, selecting: .kwic, features: features) { corpus in
            let result = try await self.repository.runKWIC(
                text: corpus.content,
                keyword: keyword,
                leftWindow: features.kwic.leftWindowValue,
                rightWindow: features.kwic.rightWindowValue,
                searchOptions: features.kwic.searchOptions
            )
            features.kwic.apply(result)
        }
    }

    func runNgram(features: WorkspaceFeatureSet) async {
        await performOpenedCorpusRunTask(.ngram, selecting: .ngram, features: features) { corpus in
            let result = try await self.repository.runNgram(
                text: corpus.content,
                n: features.ngram.ngramSizeValue
            )
            features.ngram.apply(result)
        }
    }

    func runCollocate(features: WorkspaceFeatureSet) async {
        let keyword = features.collocate.normalizedKeyword
        guard !keyword.isEmpty else {
            features.sidebar.setError("请输入 Collocate 节点词。")
            return
        }

        await performOpenedCorpusRunTask(.collocate, selecting: .collocate, features: features) { corpus in
            features.collocate.recordPendingRunConfiguration()
            let result = try await self.repository.runCollocate(
                text: corpus.content,
                keyword: keyword,
                leftWindow: features.collocate.leftWindowValue,
                rightWindow: features.collocate.rightWindowValue,
                minFreq: features.collocate.minFreqValue,
                searchOptions: features.collocate.searchOptions
            )
            features.collocate.apply(result)
        }
    }

    func runLocator(features: WorkspaceFeatureSet) async {
        guard let source = features.locator.currentSource ?? features.kwic.primaryLocatorSource else {
            features.sidebar.setError("请先运行 KWIC，Locator 会默认定位第一条结果。")
            return
        }

        await performOpenedCorpusRunTask(.locator, selecting: .locator, features: features) { corpus in
            let result = try await self.repository.runLocator(
                text: corpus.content,
                sentenceId: source.sentenceId,
                nodeIndex: source.nodeIndex,
                leftWindow: features.locator.leftWindowValue,
                rightWindow: features.locator.rightWindowValue
            )
            features.locator.apply(result, source: source)
        }
    }
}
