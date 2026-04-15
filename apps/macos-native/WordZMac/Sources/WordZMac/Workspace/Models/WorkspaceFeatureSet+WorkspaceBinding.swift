import Foundation

extension WorkspaceFeatureSet {
    @MainActor
    init(workspace: MainWorkspaceViewModel) {
        self.init(
            sidebar: workspace.sidebar,
            shell: workspace.shell,
            library: workspace.library,
            stats: workspace.stats,
            word: workspace.word,
            tokenize: workspace.tokenize,
            topics: workspace.topics,
            compare: workspace.compare,
            sentiment: workspace.sentiment,
            keyword: workspace.keyword,
            chiSquare: workspace.chiSquare,
            plot: workspace.plot,
            ngram: workspace.ngram,
            cluster: workspace.cluster,
            kwic: workspace.kwic,
            collocate: workspace.collocate,
            locator: workspace.locator,
            evidenceWorkbench: workspace.evidenceWorkbench,
            settings: workspace.settings
        )
    }
}
