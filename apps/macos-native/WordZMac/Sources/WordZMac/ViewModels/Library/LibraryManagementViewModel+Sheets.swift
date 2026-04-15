import Foundation

@MainActor
extension LibraryManagementViewModel {
    func presentCorpusInfo(_ scene: LibraryCorpusInfoSceneModel) {
        corpusInfoSheet = scene
    }

    func dismissCorpusInfo() {
        corpusInfoSheet = nil
    }

    func presentImportSummary(_ scene: LibraryImportSummarySceneModel) {
        importSummarySheet = scene
    }

    func dismissImportSummary() {
        importSummarySheet = nil
    }

    func presentMetadataEditor(
        for corpus: LibraryCorpusItem,
        sourcePresetLabels: [String] = [],
        recentSourceLabels: [String] = [],
        quickYearLabels: [String] = [],
        commonYearLabels: [String] = []
    ) {
        metadataEditorSheet = LibraryCorpusMetadataEditorSceneModel(
            id: corpus.id,
            title: corpus.name,
            subtitle: "语料元数据",
            sourceLabel: corpus.metadata.sourceLabel,
            yearLabel: corpus.metadata.yearLabel,
            genreLabel: corpus.metadata.genreLabel,
            tagsText: corpus.metadata.tagsText,
            sourcePresetLabels: sourcePresetLabels,
            recentSourceLabels: recentSourceLabels,
            quickYearLabels: quickYearLabels,
            commonYearLabels: commonYearLabels,
            isBatchEdit: false,
            allowsYearEditing: true,
            selectionCount: 1
        )
    }

    func presentBatchMetadataEditor(
        for corpora: [LibraryCorpusItem],
        sourcePresetLabels: [String] = [],
        recentSourceLabels: [String] = [],
        quickYearLabels: [String] = [],
        commonYearLabels: [String] = []
    ) {
        metadataEditorSheet = LibraryCorpusMetadataEditorSceneModel(
            id: "batch-\(corpora.map(\.id).sorted().joined(separator: "-"))",
            title: "批量元数据编辑",
            subtitle: "将更新 \(corpora.count) 条语料",
            sourceLabel: "",
            yearLabel: "",
            genreLabel: "",
            tagsText: "",
            sourcePresetLabels: sourcePresetLabels,
            recentSourceLabels: recentSourceLabels,
            quickYearLabels: quickYearLabels,
            commonYearLabels: commonYearLabels,
            isBatchEdit: true,
            allowsYearEditing: true,
            selectionCount: corpora.count
        )
    }

    func dismissMetadataEditor() {
        metadataEditorSheet = nil
    }
}
