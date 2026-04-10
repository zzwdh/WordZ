import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func refreshLibraryManagement(features: WorkspaceFeatureSet) async {
        do {
            features.library.setBusy(true)
            defer { features.library.setBusy(false) }
            try await libraryManagementCoordinator.refreshLibraryState(
                into: features.library,
                sidebar: features.sidebar
            )
            features.sidebar.clearError()
        } catch {
            features.library.setError(error.localizedDescription)
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func handleLibraryAction(
        _ action: LibraryManagementAction,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            let shouldTrackBusy: Bool
            switch action {
            case .selectFolder, .selectCorpusSet, .selectCorpus, .selectCorpusIDs, .selectRecycleEntry, .openSelectedCorpus, .quickLookSelectedCorpus, .editSelectedCorpusMetadata, .editSelectedCorporaMetadata, .importPaths:
                shouldTrackBusy = false
            default:
                shouldTrackBusy = true
            }
            if shouldTrackBusy {
                features.library.setBusy(true)
            }
            defer {
                if shouldTrackBusy {
                    features.library.setBusy(false)
                }
            }
            switch action {
            case .selectFolder, .selectCorpusSet, .selectCorpus, .selectCorpusIDs, .selectRecycleEntry, .openSelectedCorpus, .quickLookSelectedCorpus, .editSelectedCorpusMetadata, .editSelectedCorporaMetadata:
                break
            case .refresh:
                try await libraryManagementCoordinator.refreshLibraryState(into: features.library, sidebar: features.sidebar)
            case .importPaths:
                await importCorpusFromDialog(features: features, preferredRoute: preferredRoute)
            case .createFolder:
                try await libraryManagementCoordinator.createFolder(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .saveCurrentCorpusSet:
                try await libraryManagementCoordinator.saveCurrentCorpusSet(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .renameSelectedCorpus:
                try await libraryManagementCoordinator.renameSelectedCorpus(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .moveSelectedCorpusToSelectedFolder:
                try await libraryManagementCoordinator.moveSelectedCorpusToFolder(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .deleteSelectedCorpus:
                try await libraryManagementCoordinator.deleteSelectedCorpus(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .showSelectedCorpusInfo:
                try await showSelectedCorpusInfo(features: features)
            case .saveSelectedCorpusMetadata(let metadata):
                try await libraryManagementCoordinator.updateSelectedCorpusMetadata(
                    metadata,
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .applySelectedCorporaMetadataPatch(let patch):
                try await libraryManagementCoordinator.updateSelectedCorporaMetadata(
                    patch,
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .renameSelectedFolder:
                try await libraryManagementCoordinator.renameSelectedFolder(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .deleteSelectedFolder:
                try await libraryManagementCoordinator.deleteSelectedFolder(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .deleteSelectedCorpusSet:
                try await libraryManagementCoordinator.deleteSelectedCorpusSet(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .backupLibrary:
                try await libraryManagementCoordinator.backupLibrary(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .restoreLibrary:
                try await libraryManagementCoordinator.restoreLibrary(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .repairLibrary:
                try await libraryManagementCoordinator.repairLibrary(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .restoreSelectedRecycleEntry:
                try await libraryManagementCoordinator.restoreSelectedRecycleEntry(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            case .purgeSelectedRecycleEntry:
                try await libraryManagementCoordinator.purgeSelectedRecycleEntry(
                    into: features.library,
                    sidebar: features.sidebar,
                    preferredRoute: preferredRoute
                )
            }
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
        } catch {
            features.library.setError(error.localizedDescription)
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func showSelectedCorpusInfo(features: WorkspaceFeatureSet) async throws {
        guard let selectedCorpus = features.library.selectedCorpus ?? features.sidebar.selectedCorpus else {
            return
        }
        let summary = try await repository.loadCorpusInfo(corpusId: selectedCorpus.id)
        features.library.presentCorpusInfo(
            LibraryCorpusInfoSceneModel(
                id: summary.corpusId,
                title: summary.title,
                subtitle: wordZText("语料信息", "Corpus Info", mode: .system),
                folderName: summary.folderName,
                sourceType: summary.sourceType,
                sourceLabelText: summary.metadata.sourceLabel.isEmpty ? "—" : summary.metadata.sourceLabel,
                yearText: summary.metadata.yearLabel.isEmpty ? "—" : summary.metadata.yearLabel,
                genreText: summary.metadata.genreLabel.isEmpty ? "—" : summary.metadata.genreLabel,
                tagsText: summary.metadata.tagsText.isEmpty ? "—" : summary.metadata.tagsText,
                importedAtText: summary.importedAt.isEmpty ? "—" : summary.importedAt,
                encodingText: summary.detectedEncoding.isEmpty ? "—" : summary.detectedEncoding,
                tokenCountText: "\(summary.tokenCount)",
                typeCountText: "\(summary.typeCount)",
                sentenceCountText: "\(summary.sentenceCount)",
                paragraphCountText: "\(summary.paragraphCount)",
                characterCountText: "\(summary.characterCount)",
                ttrText: String(format: "%.4f", summary.ttr),
                sttrText: summary.sttr > 0 ? String(format: "%.4f", summary.sttr) : "—",
                representedPath: summary.representedPath
            )
        )
        features.library.setStatus(wordZText("已载入语料信息。", "Loaded corpus information.", mode: .system))
    }
}
