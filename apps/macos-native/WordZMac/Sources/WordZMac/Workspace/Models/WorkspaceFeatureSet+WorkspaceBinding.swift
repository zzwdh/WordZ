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
            keyword: workspace.keyword,
            chiSquare: workspace.chiSquare,
            ngram: workspace.ngram,
            kwic: workspace.kwic,
            collocate: workspace.collocate,
            locator: workspace.locator,
            settings: workspace.settings
        )
    }
}
