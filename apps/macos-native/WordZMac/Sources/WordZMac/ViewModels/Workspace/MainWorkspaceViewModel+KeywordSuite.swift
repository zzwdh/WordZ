import Foundation

import WordZWindowing
@MainActor
extension MainWorkspaceViewModel {
    func refreshKeywordSavedLists() async {
        await flowCoordinator.refreshKeywordSavedLists(features: features)
        syncResultContentSceneGraph(for: .keyword)
    }

    func saveKeywordCurrentList() async {
        await flowCoordinator.saveKeywordCurrentList(features: features)
        syncResultContentSceneGraph(for: .keyword)
    }

    func deleteKeywordSavedList(_ listID: String) async {
        await flowCoordinator.deleteKeywordSavedList(listID: listID, features: features)
        syncResultContentSceneGraph(for: .keyword)
    }

    func importKeywordSavedListsJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.importKeywordSavedListsJSON(features: features, preferredRoute: preferredWindowRoute)
        syncResultContentSceneGraph(for: .keyword)
    }

    func exportSelectedKeywordSavedListJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportKeywordSavedListsJSON(
            scope: .selected,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .keyword)
    }

    func exportAllKeywordSavedListsJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportKeywordSavedListsJSON(
            scope: .all,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .keyword)
    }

    func importKeywordReferenceWordList(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.importKeywordReferenceWordList(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .keyword)
    }

    func exportKeywordRowContext(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportKeywordRowContext(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .keyword)
    }

    func analyzeCompareSelectionInKeywordSuite() {
        let focusCorpusIDs: [String]
        switch compare.selectedReferenceSelection {
        case .automatic:
            focusCorpusIDs = compare.selectedCorpusIDsSnapshot
        case .corpus, .corpusSet:
            focusCorpusIDs = compare.selectedTargetCorpusItems().map(\.id)
        }
        keyword.applyCompareSelection(
            selectedCorpusIDs: focusCorpusIDs,
            referenceSelection: compare.selectedReferenceSelection
        )
        selectedTab = .keyword
        flowCoordinator.markWorkspaceEdited(features: features)
        syncSceneGraph(source: .navigation)
    }

    func openCompareDistributionFromKeyword() {
        if let row = keyword.selectedKeywordRow {
            compare.query = row.item
        }

        let selectedIDs = Set(keyword.resolvedFocusCorpusItems().map(\.id) + keyword.resolvedReferenceCorpusItems().map(\.id))
        if !selectedIDs.isEmpty {
            compare.selectedCorpusIDs = selectedIDs
            compare.selectionItems = compare.selectionItems.map {
                CompareSelectableCorpusSceneItem(
                    id: $0.id,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    isSelected: selectedIDs.contains($0.id)
                )
            }
            switch keyword.referenceSourceKind {
            case .singleCorpus:
                if let referenceID = keyword.selectedReferenceCorpusItem()?.id {
                    compare.selectedReferenceSelection = .corpus(referenceID)
                }
            case .namedCorpusSet:
                if let referenceSetID = keyword.selectedReferenceCorpusSet()?.id {
                    compare.selectedReferenceSelection = .corpusSet(referenceSetID)
                }
            case .importedWordList:
                compare.selectedReferenceSelection = .automatic
            }
            compare.normalizeReferenceSelection()
            compare.rebuildReferenceOptions()
            compare.rebuildScene()
        }

        selectedTab = .compare
        flowCoordinator.markWorkspaceEdited(features: features)
        syncSceneGraph(source: .navigation)
    }
}
