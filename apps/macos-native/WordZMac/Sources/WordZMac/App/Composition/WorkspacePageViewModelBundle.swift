import Foundation

@MainActor
struct WorkspacePageViewModelBundle {
    let sidebar: LibrarySidebarViewModel
    let shell: WorkspaceShellViewModel
    let library: LibraryManagementViewModel
    let stats: StatsPageViewModel
    let word: WordPageViewModel
    let tokenize: TokenizePageViewModel
    let featurePages: WorkspaceFeaturePageBundle
    let compare: ComparePageViewModel
    let keyword: KeywordPageViewModel
    let chiSquare: ChiSquarePageViewModel
    let plot: PlotPageViewModel
    let ngram: NgramPageViewModel
    let cluster: ClusterPageViewModel
    let kwic: KWICPageViewModel
    let collocate: CollocatePageViewModel
    let locator: LocatorPageViewModel
    let sourceReader: SourceReaderViewModel
    let settings: WorkspaceSettingsViewModel

    init(
        featurePages: WorkspaceFeaturePageBundle,
        libraryPages: WorkspaceLibraryPageBundle = .makeDefault()
    ) {
        self.sidebar = libraryPages.sidebar
        self.shell = WorkspaceShellViewModel()
        self.library = libraryPages.library
        self.stats = StatsPageViewModel()
        self.word = WordPageViewModel()
        self.tokenize = TokenizePageViewModel()
        self.featurePages = featurePages
        self.compare = ComparePageViewModel()
        self.keyword = KeywordPageViewModel()
        self.chiSquare = ChiSquarePageViewModel()
        self.plot = PlotPageViewModel()
        self.ngram = NgramPageViewModel()
        self.cluster = ClusterPageViewModel()
        self.kwic = KWICPageViewModel()
        self.collocate = CollocatePageViewModel()
        self.locator = LocatorPageViewModel()
        self.sourceReader = SourceReaderViewModel()
        self.settings = WorkspaceSettingsViewModel()
    }
}
