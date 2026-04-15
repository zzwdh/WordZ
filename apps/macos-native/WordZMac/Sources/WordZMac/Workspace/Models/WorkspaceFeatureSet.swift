import Foundation

struct WorkspaceFeatureSet {
    let sidebar: LibrarySidebarViewModel
    let shell: WorkspaceShellViewModel
    let library: LibraryManagementViewModel
    let stats: StatsPageViewModel
    let word: WordPageViewModel
    let tokenize: TokenizePageViewModel
    let topics: TopicsPageViewModel
    let compare: ComparePageViewModel
    let sentiment: SentimentPageViewModel
    let keyword: KeywordPageViewModel
    let chiSquare: ChiSquarePageViewModel
    let plot: PlotPageViewModel
    let ngram: NgramPageViewModel
    let cluster: ClusterPageViewModel
    let kwic: KWICPageViewModel
    let collocate: CollocatePageViewModel
    let locator: LocatorPageViewModel
    let evidenceWorkbench: EvidenceWorkbenchViewModel
    let settings: WorkspaceSettingsViewModel

    @MainActor
    init(
        sidebar: LibrarySidebarViewModel,
        shell: WorkspaceShellViewModel,
        library: LibraryManagementViewModel,
        stats: StatsPageViewModel,
        word: WordPageViewModel = WordPageViewModel(),
        tokenize: TokenizePageViewModel = TokenizePageViewModel(),
        topics: TopicsPageViewModel = TopicsPageViewModel(),
        compare: ComparePageViewModel,
        sentiment: SentimentPageViewModel = SentimentPageViewModel(),
        keyword: KeywordPageViewModel = KeywordPageViewModel(),
        chiSquare: ChiSquarePageViewModel,
        plot: PlotPageViewModel = PlotPageViewModel(),
        ngram: NgramPageViewModel,
        cluster: ClusterPageViewModel = ClusterPageViewModel(),
        kwic: KWICPageViewModel,
        collocate: CollocatePageViewModel,
        locator: LocatorPageViewModel,
        evidenceWorkbench: EvidenceWorkbenchViewModel = EvidenceWorkbenchViewModel(),
        settings: WorkspaceSettingsViewModel
    ) {
        self.sidebar = sidebar
        self.shell = shell
        self.library = library
        self.stats = stats
        self.word = word
        self.tokenize = tokenize
        self.topics = topics
        self.compare = compare
        self.sentiment = sentiment
        self.keyword = keyword
        self.chiSquare = chiSquare
        self.plot = plot
        self.ngram = ngram
        self.cluster = cluster
        self.kwic = kwic
        self.collocate = collocate
        self.locator = locator
        self.evidenceWorkbench = evidenceWorkbench
        self.settings = settings
    }
}
