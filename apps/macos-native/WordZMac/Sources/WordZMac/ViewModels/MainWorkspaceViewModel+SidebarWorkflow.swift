import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func handleMetadataFiltersChanged(selectionChanged: Bool) {
        let filteredIDs = Set(sidebar.filteredCorpora.map(\.id))
        library.syncSidebarSelection(sidebar.selectedCorpusID)

        let currentKeywordTarget = keyword.targetCorpusIDSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentKeywordTarget.isEmpty, !filteredIDs.contains(currentKeywordTarget) {
            keyword.handle(.changeTargetCorpus(sidebar.selectedCorpusID ?? ""))
        }

        let currentKeywordReference = keyword.referenceCorpusIDSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentKeywordReference.isEmpty, !filteredIDs.contains(currentKeywordReference) {
            keyword.handle(.changeReferenceCorpus(""))
        }

        if selectionChanged {
            flowCoordinator.handleCorpusSelectionChange(features: features)
            syncSceneGraph(source: .librarySelection)
        } else {
            flowCoordinator.markWorkspaceEdited(features: features)
            syncSceneGraph(source: .librarySelection)
        }
    }

    var filteredWorkflowLibrarySnapshot: LibrarySnapshot {
        LibrarySnapshot(
            folders: sidebar.librarySnapshot.folders,
            corpora: sidebar.filteredCorpora
        )
    }

    var sidebarTargetCorpusID: String? {
        if selectedTab == .keyword {
            let keywordTarget = keyword.targetCorpusIDSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !keywordTarget.isEmpty {
                return keywordTarget
            }
        }
        return sidebar.selectedCorpusID
    }

    func syncLocatorSourceFromKWIC() {
        locator.updateSource(kwic.primaryLocatorSource)
    }

    func syncWorkflowLibraryState() {
        compare.syncLibrarySnapshot(filteredWorkflowLibrarySnapshot)
        keyword.syncLibrarySnapshot(filteredWorkflowLibrarySnapshot)
        library.syncSidebarSelection(sidebar.selectedCorpusID)
    }
}
