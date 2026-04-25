import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func restoreWorkspaceAnnotationState(from snapshot: WorkspaceSnapshotSummary?) {
        let state = snapshot.map {
            WorkspaceAnnotationState(
                profile: $0.annotationProfile,
                lexicalClasses: $0.annotationLexicalClasses,
                scripts: $0.annotationScripts
            )
        } ?? .default
        applyWorkspaceAnnotationState(state, updatePages: true)
    }

    func synchronizeWorkspaceAnnotationStateFromPages() {
        let state = WorkspaceAnnotationState(
            profile: tokenize.annotationProfile,
            lexicalClasses: Array(keyword.selectedLexicalClasses),
            scripts: Array(keyword.selectedScripts)
        )
        applyWorkspaceAnnotationState(state, updatePages: false)
    }

    func setAnnotationProfile(_ profile: WorkspaceAnnotationProfile) {
        guard annotationState.profile != profile else { return }
        var nextState = annotationState
        nextState.profile = profile
        applyWorkspaceAnnotationState(nextState, updatePages: true)
    }

    func toggleAnnotationScript(_ script: TokenScript) {
        var nextScripts = annotationState.scriptSet
        if nextScripts.contains(script) {
            nextScripts.remove(script)
        } else {
            nextScripts.insert(script)
        }

        var nextState = annotationState
        nextState.scripts = Array(nextScripts)
        applyWorkspaceAnnotationState(nextState, updatePages: true)
    }

    func toggleAnnotationLexicalClass(_ lexicalClass: TokenLexicalClass) {
        var nextClasses = annotationState.lexicalClassSet
        if nextClasses.contains(lexicalClass) {
            nextClasses.remove(lexicalClass)
        } else {
            nextClasses.insert(lexicalClass)
        }

        var nextState = annotationState
        nextState.lexicalClasses = Array(nextClasses)
        applyWorkspaceAnnotationState(nextState, updatePages: true)
    }

    func clearAnnotationFilters() {
        guard !annotationState.lexicalClasses.isEmpty || !annotationState.scripts.isEmpty else { return }
        var nextState = annotationState
        nextState.lexicalClasses = []
        nextState.scripts = []
        applyWorkspaceAnnotationState(nextState, updatePages: true)
    }

    func annotationSummary(in mode: AppLanguageMode) -> String {
        annotationState.summary(in: mode)
    }

    private func applyWorkspaceAnnotationState(
        _ state: WorkspaceAnnotationState,
        updatePages: Bool
    ) {
        let normalizedState = WorkspaceAnnotationState(
            profile: state.profile,
            lexicalClasses: state.lexicalClasses,
            scripts: state.scripts
        )

        let needsPageSync = tokenize.annotationProfile != normalizedState.profile ||
            keyword.annotationProfile != normalizedState.profile ||
            keyword.selectedScripts != normalizedState.scriptSet ||
            keyword.selectedLexicalClasses != normalizedState.lexicalClassSet ||
            word.annotationState != normalizedState ||
            kwic.annotationState != normalizedState ||
            collocate.annotationState != normalizedState ||
            cluster.annotationState != normalizedState ||
            topics.annotationState != normalizedState ||
            compare.annotationState != normalizedState ||
            sentiment.annotationState != normalizedState

        guard annotationState != normalizedState || (updatePages && needsPageSync) else {
            shell.applyAnnotationState(normalizedState)
            return
        }

        isApplyingWorkspaceAnnotationState = true
        defer { isApplyingWorkspaceAnnotationState = false }

        annotationState = normalizedState
        shell.applyAnnotationState(normalizedState)
        sourceReader.applyAnnotationState(normalizedState)

        guard updatePages else { return }
        tokenize.applyWorkspaceAnnotationProfile(normalizedState.profile)
        keyword.applyWorkspaceAnnotationState(normalizedState)
        word.applyWorkspaceAnnotationState(normalizedState)
        kwic.applyWorkspaceAnnotationState(normalizedState)
        collocate.applyWorkspaceAnnotationState(normalizedState)
        cluster.applyWorkspaceAnnotationState(normalizedState)
        topics.applyWorkspaceAnnotationState(normalizedState)
        compare.applyWorkspaceAnnotationState(normalizedState)
        sentiment.applyWorkspaceAnnotationState(normalizedState)
    }
}
