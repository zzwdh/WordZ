import Foundation

@MainActor
final class LibraryManagementViewModel: ObservableObject {
    @Published var selectedFolderID: String? {
        didSet { syncScene() }
    }
    @Published var selectedCorpusID: String? {
        didSet {
            if corpusInfoSheet?.id != selectedCorpusID {
                corpusInfoSheet = nil
            }
            if metadataEditorSheet?.id != selectedCorpusID {
                metadataEditorSheet = nil
            }
            syncScene()
        }
    }
    @Published var selectedRecycleEntryID: String? {
        didSet { syncScene() }
    }
    @Published var preserveHierarchy = true {
        didSet { syncScene() }
    }
    @Published var corpusInfoSheet: LibraryCorpusInfoSceneModel?
    @Published var metadataEditorSheet: LibraryCorpusMetadataEditorSceneModel?
    @Published private(set) var librarySnapshot = LibrarySnapshot.empty
    @Published private(set) var recycleSnapshot = RecycleBinSnapshot.empty
    @Published private(set) var scene = LibraryManagementSceneModel.empty

    private var context = WorkspaceSceneContext.empty
    private var statusMessage = ""
    private var isBusy = false

    var selectedFolder: LibraryFolderItem? {
        guard let selectedFolderID else { return nil }
        return librarySnapshot.folders.first(where: { $0.id == selectedFolderID })
    }

    var selectedCorpus: LibraryCorpusItem? {
        guard let selectedCorpusID else { return nil }
        return librarySnapshot.corpora.first(where: { $0.id == selectedCorpusID })
    }

    var selectedRecycleEntry: RecycleBinEntry? {
        guard let selectedRecycleEntryID else { return nil }
        return recycleSnapshot.entries.first(where: { $0.id == selectedRecycleEntryID })
    }

    func applyBootstrap(_ snapshot: LibrarySnapshot) {
        applyLibrarySnapshot(snapshot)
    }

    func applyContext(_ context: WorkspaceSceneContext) {
        self.context = context
        syncScene()
    }

    func applyLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        librarySnapshot = snapshot
        if let selectedFolderID, !snapshot.folders.contains(where: { $0.id == selectedFolderID }) {
            self.selectedFolderID = nil
        }
        if let selectedCorpusID, !snapshot.corpora.contains(where: { $0.id == selectedCorpusID }) {
            self.selectedCorpusID = nil
        }
        syncScene()
    }

    func applyRecycleSnapshot(_ snapshot: RecycleBinSnapshot) {
        recycleSnapshot = snapshot
        if let selectedRecycleEntryID, !snapshot.entries.contains(where: { $0.id == selectedRecycleEntryID }) {
            self.selectedRecycleEntryID = snapshot.entries.first?.id
        }
        syncScene()
    }

    func syncSidebarSelection(_ selectedCorpusID: String?) {
        self.selectedCorpusID = selectedCorpusID
        syncScene()
    }

    func selectFolder(_ folderID: String?) {
        selectedFolderID = folderID
        if let selectedCorpus, let folderID, selectedCorpus.folderId != folderID {
            selectedCorpusID = nil
        }
        selectedRecycleEntryID = nil
    }

    func selectCorpus(_ corpusID: String?) {
        selectedCorpusID = corpusID
        if corpusID != nil {
            selectedRecycleEntryID = nil
        }
    }

    func selectRecycleEntry(_ recycleEntryID: String?) {
        selectedRecycleEntryID = recycleEntryID
        if recycleEntryID != nil {
            selectedCorpusID = nil
        }
    }

    func setBusy(_ isBusy: Bool) {
        self.isBusy = isBusy
        syncScene()
    }

    func setStatus(_ message: String) {
        statusMessage = message
        syncScene()
    }

    func setError(_ message: String) {
        statusMessage = message
        syncScene()
    }

    func presentCorpusInfo(_ scene: LibraryCorpusInfoSceneModel) {
        corpusInfoSheet = scene
    }

    func dismissCorpusInfo() {
        corpusInfoSheet = nil
    }

    func presentMetadataEditor(for corpus: LibraryCorpusItem) {
        metadataEditorSheet = LibraryCorpusMetadataEditorSceneModel(
            id: corpus.id,
            title: corpus.name,
            subtitle: "语料元数据",
            sourceLabel: corpus.metadata.sourceLabel,
            yearLabel: corpus.metadata.yearLabel,
            genreLabel: corpus.metadata.genreLabel,
            tagsText: corpus.metadata.tagsText
        )
    }

    func dismissMetadataEditor() {
        metadataEditorSheet = nil
    }

    private func syncScene() {
        let corporaByFolderID = Dictionary(grouping: librarySnapshot.corpora, by: \.folderId)
        let visibleCorpora = librarySnapshot.corpora.filter { corpus in
            guard let selectedFolderID else { return true }
            return corpus.folderId == selectedFolderID
        }
        let folders = librarySnapshot.folders.map { folder in
            let corpusCount = corporaByFolderID[folder.id]?.count ?? 0
            return LibraryManagementFolderSceneItem(
                id: folder.id,
                title: folder.name,
                subtitle: "\(corpusCount) 条语料",
                isSelected: folder.id == selectedFolderID
            )
        }
        let corpora = visibleCorpora.map {
            LibraryManagementCorpusSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: $0.folderName,
                sourceType: $0.sourceType,
                metadataSummary: $0.metadata.compactSummary(in: WordZLocalization.shared.effectiveMode),
                isSelected: $0.id == selectedCorpusID
            )
        }
        let recycleEntries = recycleSnapshot.entries.map {
            LibraryManagementRecycleSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: $0.originalFolderName.isEmpty ? $0.deletedAt : "\($0.originalFolderName) · \($0.deletedAt)",
                typeLabel: $0.type
            )
        }
        let librarySummary = selectedFolder == nil
            ? "文件夹 \(librarySnapshot.folders.count) · 语料 \(librarySnapshot.corpora.count)"
            : "文件夹 \(librarySnapshot.folders.count) · 当前目录 \(visibleCorpora.count) 条语料"
        let recycleSummary = "回收站 \(recycleSnapshot.totalCount) 项"

        scene = LibraryManagementSceneModel(
            librarySummary: librarySummary,
            recycleSummary: recycleSummary,
            statusMessage: statusMessage.isEmpty
                ? (isBusy ? "正在处理语料库操作…" : "语料库管理已就绪")
                : statusMessage,
            preserveHierarchy: preserveHierarchy,
            folders: folders,
            corpora: corpora,
            recycleEntries: recycleEntries,
            selectedFolderID: selectedFolderID,
            selectedCorpusID: selectedCorpusID,
            selectedRecycleEntryID: selectedRecycleEntryID,
            inspector: buildInspector(
                visibleCorpora: visibleCorpora,
                corporaByFolderID: corporaByFolderID
            )
        )
    }

    private func buildInspector(
        visibleCorpora: [LibraryCorpusItem],
        corporaByFolderID: [String: [LibraryCorpusItem]]
    ) -> LibraryManagementInspectorSceneModel {
        if let selectedCorpus {
            return LibraryManagementInspectorSceneModel(
                title: selectedCorpus.name,
                subtitle: "语料 · \(selectedCorpus.sourceType.uppercased())",
                details: [
                    .init(id: "folder", title: "文件夹", value: selectedCorpus.folderName),
                    .init(id: "source", title: "来源类型", value: selectedCorpus.sourceType),
                    .init(id: "source-label", title: "来源", value: selectedCorpus.metadata.sourceLabel.isEmpty ? "—" : selectedCorpus.metadata.sourceLabel),
                    .init(id: "year-label", title: "年份", value: selectedCorpus.metadata.yearLabel.isEmpty ? "—" : selectedCorpus.metadata.yearLabel),
                    .init(id: "genre-label", title: "体裁", value: selectedCorpus.metadata.genreLabel.isEmpty ? "—" : selectedCorpus.metadata.genreLabel),
                    .init(id: "tags", title: "标签", value: selectedCorpus.metadata.tagsText.isEmpty ? "—" : selectedCorpus.metadata.tagsText),
                    .init(id: "scope", title: "当前视图", value: selectedFolder?.name ?? "全部语料")
                ],
                actions: [
                    .init(id: "open", title: "打开语料", role: .primary, action: .openSelectedCorpus),
                    .init(id: "preview", title: "快速预览", role: .normal, action: .quickLookSelectedCorpus),
                    .init(id: "info", title: "语料信息", role: .normal, action: .showSelectedCorpusInfo),
                    .init(id: "edit-metadata", title: "编辑元数据", role: .normal, action: .editSelectedCorpusMetadata),
                    .init(id: "rename-corpus", title: "重命名", role: .normal, action: .renameSelectedCorpus),
                    .init(id: "move-corpus", title: "移动到所选文件夹", role: .normal, action: .moveSelectedCorpusToSelectedFolder),
                    .init(id: "delete-corpus", title: "删除", role: .destructive, action: .deleteSelectedCorpus)
                ]
            )
        }

        if let selectedRecycleEntry {
            return LibraryManagementInspectorSceneModel(
                title: selectedRecycleEntry.name,
                subtitle: "回收站项目 · \(selectedRecycleEntry.type)",
                details: [
                    .init(id: "deleted-at", title: "删除时间", value: selectedRecycleEntry.deletedAt),
                    .init(id: "origin-folder", title: "原始文件夹", value: selectedRecycleEntry.originalFolderName),
                    .init(id: "item-count", title: "项目数量", value: "\(selectedRecycleEntry.itemCount)")
                ],
                actions: [
                    .init(id: "restore-recycle", title: "恢复项目", role: .primary, action: .restoreSelectedRecycleEntry),
                    .init(id: "purge-recycle", title: "彻底删除", role: .destructive, action: .purgeSelectedRecycleEntry)
                ]
            )
        }

        if let selectedFolder {
            let folderCorpora = corporaByFolderID[selectedFolder.id] ?? []
            return LibraryManagementInspectorSceneModel(
                title: selectedFolder.name,
                subtitle: "文件夹",
                details: [
                    .init(id: "folder-corpus-count", title: "语料数量", value: "\(folderCorpora.count)"),
                    .init(id: "visible-count", title: "当前视图", value: "\(visibleCorpora.count) 条语料"),
                    .init(id: "preserve-hierarchy", title: "导入保留层级", value: preserveHierarchy ? "开启" : "关闭")
                ],
                actions: [
                    .init(id: "import-folder", title: "导入到此文件夹", role: .primary, action: .importPaths),
                    .init(id: "rename-folder", title: "重命名文件夹", role: .normal, action: .renameSelectedFolder),
                    .init(id: "delete-folder", title: "删除文件夹", role: .destructive, action: .deleteSelectedFolder)
                ]
            )
        }

        return LibraryManagementInspectorSceneModel(
            title: "全部语料",
            subtitle: "选择一个文件夹、语料或回收站项目可查看详情。",
            details: [
                .init(id: "folder-total", title: "文件夹数量", value: "\(librarySnapshot.folders.count)"),
                .init(id: "corpus-total", title: "语料数量", value: "\(librarySnapshot.corpora.count)"),
                .init(id: "recycle-total", title: "回收站项目", value: "\(recycleSnapshot.totalCount)")
            ],
            actions: [
                .init(id: "import-root", title: "导入语料", role: .primary, action: .importPaths),
                .init(id: "create-folder-root", title: "新建文件夹", role: .normal, action: .createFolder),
                .init(id: "repair-library-root", title: "修复语料库", role: .normal, action: .repairLibrary)
            ]
        )
    }
}
