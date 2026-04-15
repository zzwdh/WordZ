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
        let currentClusterReference = cluster.referenceCorpusID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentClusterReference.isEmpty, !filteredIDs.contains(currentClusterReference) {
            cluster.handle(.changeReferenceCorpus(nil))
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
            corpora: sidebar.filteredCorpora,
            corpusSets: sidebar.librarySnapshot.corpusSets
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

    var sidebarReferenceCorpusID: String? {
        switch selectedTab {
        case .keyword:
            let keywordReference = keyword.referenceCorpusIDSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            return keywordReference.isEmpty ? nil : keywordReference
        case .cluster:
            let clusterReference = cluster.referenceCorpusID.trimmingCharacters(in: .whitespacesAndNewlines)
            return clusterReference.isEmpty ? nil : clusterReference
        default:
            return nil
        }
    }

    var sidebarReferenceSummaryOverride: String? {
        switch selectedTab {
        case .keyword:
            return keyword.workflowReferenceSummary
        case .cluster:
            guard let referenceID = sidebarReferenceCorpusID,
                  let corpus = sidebar.filteredCorpora.first(where: { $0.id == referenceID }) else {
                return nil
            }
            return corpus.name
        default:
            return nil
        }
    }

    var sidebarReferenceDetailOverride: String? {
        switch selectedTab {
        case .keyword:
            return keyword.workflowReferenceDetail
        case .cluster:
            guard let referenceID = sidebarReferenceCorpusID,
                  let corpus = sidebar.filteredCorpora.first(where: { $0.id == referenceID }) else {
                return nil
            }
            return corpus.folderName
        default:
            return nil
        }
    }

    func syncLocatorSourceFromKWIC() {
        locator.updateSource(kwic.primaryLocatorSource)
    }

    func syncWorkflowLibraryState() {
        compare.syncLibrarySnapshot(filteredWorkflowLibrarySnapshot)
        sentiment.syncLibrarySnapshot(filteredWorkflowLibrarySnapshot)
        keyword.syncLibrarySnapshot(filteredWorkflowLibrarySnapshot)
        cluster.syncLibrarySnapshot(filteredWorkflowLibrarySnapshot)
        library.syncSidebarSelection(sidebar.selectedCorpusID)
    }
}
