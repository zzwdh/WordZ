import Foundation
import WordZShared

@MainActor
final class WorkspaceSceneGraphStore: ObservableObject {
    @Published private(set) var graph = WorkspaceSceneGraph.empty
    private(set) var graphRevision = 0
    private(set) var contentRevisions = WorkspaceSceneGraphContentRevisions.empty
    private let resultNodeBuilderFactory: any WorkspaceResultSceneNodeBuildingFactory

    init(
        resultNodeBuilderFactory: any WorkspaceResultSceneNodeBuildingFactory = DefaultWorkspaceResultSceneNodeBuilderFactory()
    ) {
        self.resultNodeBuilderFactory = resultNodeBuilderFactory
    }

    func replaceGraph(with graph: WorkspaceSceneGraph) {
        let changedFields = WorkspaceSceneGraphChangedFields.comparing(graph, to: self.graph)
        guard changedFields.hasChanges else { return }
        applyGraph(graph, changedFields: changedFields)
    }

    func makeResultNodeBuilder(languageMode: AppLanguageMode) -> any WorkspaceResultSceneNodeBuilding {
        resultNodeBuilderFactory.make(languageMode: languageMode)
    }

    func applyGraph(
        _ graph: WorkspaceSceneGraph,
        changedFields: WorkspaceSceneGraphChangedFields
    ) {
        self.graph = graph
        graphRevision &+= 1
        contentRevisions.bump(changedFields)
        contentRevisions.graph = graphRevision
    }
}

struct WorkspaceSceneGraphContentRevisions: Equatable {
    var graph: Int
    var context: Int
    var sidebar: Int
    var shell: Int
    var library: Int
    var settings: Int
    var activeTab: Int
    var word: Int
    var tokenize: Int
    var stats: Int
    var topics: Int
    var compare: Int
    var sentiment: Int
    var keyword: Int
    var chiSquare: Int
    var plot: Int
    var ngram: Int
    var cluster: Int
    var kwic: Int
    var collocate: Int
    var locator: Int

    static let empty = WorkspaceSceneGraphContentRevisions(
        graph: 0,
        context: 0,
        sidebar: 0,
        shell: 0,
        library: 0,
        settings: 0,
        activeTab: 0,
        word: 0,
        tokenize: 0,
        stats: 0,
        topics: 0,
        compare: 0,
        sentiment: 0,
        keyword: 0,
        chiSquare: 0,
        plot: 0,
        ngram: 0,
        cluster: 0,
        kwic: 0,
        collocate: 0,
        locator: 0
    )

    mutating func bump(_ fields: WorkspaceSceneGraphChangedFields) {
        if fields.context { context &+= 1 }
        if fields.sidebar { sidebar &+= 1 }
        if fields.shell { shell &+= 1 }
        if fields.library { library &+= 1 }
        if fields.settings { settings &+= 1 }
        if fields.activeTab { activeTab &+= 1 }
        if fields.word { word &+= 1 }
        if fields.tokenize { tokenize &+= 1 }
        if fields.stats { stats &+= 1 }
        if fields.topics { topics &+= 1 }
        if fields.compare { compare &+= 1 }
        if fields.sentiment { sentiment &+= 1 }
        if fields.keyword { keyword &+= 1 }
        if fields.chiSquare { chiSquare &+= 1 }
        if fields.plot { plot &+= 1 }
        if fields.ngram { ngram &+= 1 }
        if fields.cluster { cluster &+= 1 }
        if fields.kwic { kwic &+= 1 }
        if fields.collocate { collocate &+= 1 }
        if fields.locator { locator &+= 1 }
    }

    func resultRevision(for tab: WorkspaceDetailTab) -> Int {
        switch tab {
        case .stats:
            return stats
        case .word:
            return word
        case .tokenize:
            return tokenize
        case .topics:
            return topics
        case .compare:
            return compare
        case .sentiment:
            return sentiment
        case .keyword:
            return keyword
        case .chiSquare:
            return chiSquare
        case .plot:
            return plot
        case .ngram:
            return ngram
        case .cluster:
            return cluster
        case .kwic:
            return kwic
        case .collocate:
            return collocate
        case .locator:
            return locator
        case .library, .settings:
            return 0
        }
    }
}

struct WorkspaceSceneGraphChangedFields: Equatable {
    var context = false
    var sidebar = false
    var shell = false
    var library = false
    var settings = false
    var activeTab = false
    var word = false
    var tokenize = false
    var stats = false
    var topics = false
    var compare = false
    var sentiment = false
    var keyword = false
    var chiSquare = false
    var plot = false
    var ngram = false
    var cluster = false
    var kwic = false
    var collocate = false
    var locator = false

    var hasChanges: Bool {
        context || sidebar || shell || library || settings || activeTab ||
            word || tokenize || stats || topics || compare || sentiment ||
            keyword || chiSquare || plot || ngram || cluster || kwic ||
            collocate || locator
    }

    static func comparing(
        _ next: WorkspaceSceneGraph,
        to current: WorkspaceSceneGraph
    ) -> WorkspaceSceneGraphChangedFields {
        WorkspaceSceneGraphChangedFields(
            context: next.context != current.context,
            sidebar: next.sidebar != current.sidebar,
            shell: next.shell != current.shell,
            library: next.library != current.library,
            settings: next.settings != current.settings,
            activeTab: next.activeTab != current.activeTab,
            word: next.word != current.word,
            tokenize: next.tokenize != current.tokenize,
            stats: next.stats != current.stats,
            topics: next.topics != current.topics,
            compare: next.compare != current.compare,
            sentiment: next.sentiment != current.sentiment,
            keyword: next.keyword != current.keyword,
            chiSquare: next.chiSquare != current.chiSquare,
            plot: next.plot != current.plot,
            ngram: next.ngram != current.ngram,
            cluster: next.cluster != current.cluster,
            kwic: next.kwic != current.kwic,
            collocate: next.collocate != current.collocate,
            locator: next.locator != current.locator
        )
    }
}
