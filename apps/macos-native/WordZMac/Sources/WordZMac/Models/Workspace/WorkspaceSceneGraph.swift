import Foundation

struct WorkspaceResultSceneNode: Equatable {
    let title: String
    let status: String
    let totalRows: Int
    let visibleRows: Int
    let hasResult: Bool
    let table: NativeTableDescriptor
    let tableSnapshot: ResultTableSnapshot
    let exportMetadataLines: [String]

    var tableRows: [NativeTableRowDescriptor] {
        tableSnapshot.rows
    }

    init(
        title: String,
        status: String,
        totalRows: Int,
        visibleRows: Int,
        hasResult: Bool,
        table: NativeTableDescriptor,
        tableSnapshot: ResultTableSnapshot,
        exportMetadataLines: [String] = []
    ) {
        self.title = title
        self.status = status
        self.totalRows = totalRows
        self.visibleRows = visibleRows
        self.hasResult = hasResult
        self.table = table
        self.tableSnapshot = tableSnapshot
        self.exportMetadataLines = exportMetadataLines
    }

    init(
        title: String,
        status: String,
        totalRows: Int,
        visibleRows: Int,
        hasResult: Bool,
        table: NativeTableDescriptor,
        tableRows: [NativeTableRowDescriptor],
        exportMetadataLines: [String] = []
    ) {
        self.init(
            title: title,
            status: status,
            totalRows: totalRows,
            visibleRows: visibleRows,
            hasResult: hasResult,
            table: table,
            tableSnapshot: ResultTableSnapshot.stable(rows: tableRows),
            exportMetadataLines: exportMetadataLines
        )
    }

    static func empty(title: String, status: String) -> WorkspaceResultSceneNode {
        WorkspaceResultSceneNode(
            title: title,
            status: status,
            totalRows: 0,
            visibleRows: 0,
            hasResult: false,
            table: .empty,
            tableSnapshot: .empty,
            exportMetadataLines: []
        )
    }

    var exportSnapshot: NativeTableExportSnapshot? {
        guard isExportable else { return nil }
        return NativeTableExportSnapshot(
            suggestedBaseName: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            table: table,
            rows: tableRows,
            metadataLines: exportMetadataLines
        )
    }

    var isExportable: Bool {
        hasResult && !table.visibleColumns.isEmpty && !tableSnapshot.rows.isEmpty
    }

    static func == (lhs: WorkspaceResultSceneNode, rhs: WorkspaceResultSceneNode) -> Bool {
        lhs.title == rhs.title &&
            lhs.status == rhs.status &&
            lhs.totalRows == rhs.totalRows &&
            lhs.visibleRows == rhs.visibleRows &&
            lhs.hasResult == rhs.hasResult &&
            lhs.table == rhs.table &&
            lhs.tableSnapshot.version == rhs.tableSnapshot.version &&
            lhs.exportMetadataLines == rhs.exportMetadataLines
    }
}

struct WorkspaceSceneGraph: Equatable {
    let context: WorkspaceSceneContext
    let sidebar: WorkspaceSidebarSceneModel
    let shell: WorkspaceShellSceneModel
    let library: LibraryManagementSceneModel
    let settings: SettingsPaneSceneModel
    let activeTab: WorkspaceDetailTab
    let word: WorkspaceResultSceneNode
    let tokenize: WorkspaceResultSceneNode
    let stats: WorkspaceResultSceneNode
    let topics: WorkspaceResultSceneNode
    let compare: WorkspaceResultSceneNode
    let sentiment: WorkspaceResultSceneNode
    let keyword: WorkspaceResultSceneNode
    let chiSquare: WorkspaceResultSceneNode
    let plot: WorkspaceResultSceneNode
    let ngram: WorkspaceResultSceneNode
    let cluster: WorkspaceResultSceneNode
    let kwic: WorkspaceResultSceneNode
    let collocate: WorkspaceResultSceneNode
    let locator: WorkspaceResultSceneNode

    init(
        context: WorkspaceSceneContext,
        sidebar: WorkspaceSidebarSceneModel,
        shell: WorkspaceShellSceneModel,
        library: LibraryManagementSceneModel,
        settings: SettingsPaneSceneModel,
        activeTab: WorkspaceDetailTab,
        word: WorkspaceResultSceneNode = .empty(title: "Word", status: "尚未生成 Word 结果"),
        tokenize: WorkspaceResultSceneNode = .empty(title: "Tokenize", status: "尚未生成分词结果"),
        stats: WorkspaceResultSceneNode,
        topics: WorkspaceResultSceneNode = .empty(title: "Topics", status: "尚未生成 Topics 结果"),
        compare: WorkspaceResultSceneNode,
        sentiment: WorkspaceResultSceneNode = .empty(title: "Sentiment", status: "尚未生成 Sentiment 结果"),
        keyword: WorkspaceResultSceneNode = .empty(title: "Keyword", status: "尚未生成关键词结果"),
        chiSquare: WorkspaceResultSceneNode,
        plot: WorkspaceResultSceneNode = .empty(title: "Plot", status: "尚未生成 Plot 结果"),
        ngram: WorkspaceResultSceneNode,
        cluster: WorkspaceResultSceneNode = .empty(title: "Cluster", status: "尚未生成 Cluster 结果"),
        kwic: WorkspaceResultSceneNode,
        collocate: WorkspaceResultSceneNode,
        locator: WorkspaceResultSceneNode
    ) {
        self.context = context
        self.sidebar = sidebar
        self.shell = shell
        self.library = library
        self.settings = settings
        self.activeTab = activeTab
        self.word = word
        self.tokenize = tokenize
        self.stats = stats
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
    }

    static let empty = WorkspaceSceneGraph(
        context: .empty,
        sidebar: .empty,
        shell: WorkspaceShellSceneModel(
            workspaceSummary: WorkspaceSceneContext.empty.workspaceSummary,
            buildSummary: WorkspaceSceneContext.empty.buildSummary,
            annotationSummary: WorkspaceAnnotationState.default.summary(in: .system),
            toolbar: WorkspaceToolbarSceneModel(items: [])
        ),
        library: .empty,
        settings: .empty,
        activeTab: .stats,
        word: .empty(title: "Word", status: "尚未生成 Word 结果"),
        tokenize: .empty(title: "Tokenize", status: "尚未生成分词结果"),
        stats: .empty(title: "Stats", status: "尚未生成统计结果"),
        topics: .empty(title: "Topics", status: "尚未生成 Topics 结果"),
        compare: .empty(title: "Compare", status: "尚未生成 Compare 结果"),
        sentiment: .empty(title: "Sentiment", status: "尚未生成 Sentiment 结果"),
        keyword: .empty(title: "Keyword", status: "尚未生成关键词结果"),
        chiSquare: .empty(title: "Chi-Square", status: "尚未生成 Chi-Square 结果"),
        plot: .empty(title: "Plot", status: "尚未生成 Plot 结果"),
        ngram: .empty(title: "N-Gram", status: "尚未生成 N-Gram 结果"),
        cluster: .empty(title: "Cluster", status: "尚未生成 Cluster 结果"),
        kwic: .empty(title: "KWIC", status: "尚未生成 KWIC 结果"),
        collocate: .empty(title: "Collocate", status: "尚未生成 Collocate 结果"),
        locator: .empty(title: "Locator", status: "尚未生成 Locator 结果")
    )
}
