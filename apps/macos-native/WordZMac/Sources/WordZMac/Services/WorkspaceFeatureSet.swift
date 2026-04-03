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
    let chiSquare: ChiSquarePageViewModel
    let ngram: NgramPageViewModel
    let wordCloud: WordCloudPageViewModel
    let kwic: KWICPageViewModel
    let collocate: CollocatePageViewModel
    let locator: LocatorPageViewModel
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
        chiSquare: ChiSquarePageViewModel,
        ngram: NgramPageViewModel,
        wordCloud: WordCloudPageViewModel,
        kwic: KWICPageViewModel,
        collocate: CollocatePageViewModel,
        locator: LocatorPageViewModel,
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
        self.chiSquare = chiSquare
        self.ngram = ngram
        self.wordCloud = wordCloud
        self.kwic = kwic
        self.collocate = collocate
        self.locator = locator
        self.settings = settings
    }
}
