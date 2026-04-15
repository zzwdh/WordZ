import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func applyInitialHostState() {
        let initialHostPreferences = hostPreferencesStore.load()
        settings.applyHostPreferences(initialHostPreferences)
        lastPersistedTaskHistory = initialHostPreferences.taskHistory
        updateState = NativeUpdateStateSnapshot(
            currentVersion: "",
            latestVersion: "",
            releaseURL: "",
            statusMessage: initialHostPreferences.lastUpdateStatus,
            updateAvailable: false,
            isChecking: false,
            isDownloading: false,
            downloadProgress: nil,
            downloadedUpdateVersion: initialHostPreferences.downloadedUpdateVersion,
            downloadedUpdateName: initialHostPreferences.downloadedUpdateName,
            downloadedUpdatePath: initialHostPreferences.downloadedUpdatePath,
            releaseTitle: "",
            publishedAt: "",
            releaseNotes: [],
            assetName: ""
        )
        settings.applyUpdateState(updateState)
        menuBarStatus.applyUpdateState(updateState)
        taskCenter.restoreHistory(initialHostPreferences.taskHistory)
        menuBarStatus.applyTaskCenterScene(taskCenter.scene)
        taskCenter.onSceneChange = { [weak self] scene in
            self?.menuBarStatus.applyTaskCenterScene(scene)
        }
        taskCenter.onHistoryChange = { [weak self] history in
            self?.persistTaskHistory(history)
        }
        taskCenter.onTerminalEvent = { [weak self] item in
            guard let self else { return }
            Task { @MainActor in
                await self.emitHostNotificationForTask(item)
            }
        }
    }

    func bindWorkspaceCallbacks() {
        settings.onLanguageModeChange = { [weak self] in
            self?.syncSceneGraph()
        }

        sidebar.onSelectionChange = { [weak self] in
            guard let self else { return }
            guard !self.isLibrarySelectionSceneSyncSuppressed else { return }
            self.flowCoordinator.handleCorpusSelectionChange(features: self.features)
            self.syncSceneGraph(source: .librarySelection)
        }
        sidebar.onMetadataFilterChange = { [weak self] selectionChanged in
            guard let self else { return }
            self.handleMetadataFiltersChanged(selectionChanged: selectionChanged)
        }
        shell.onTabChange = { [weak self] in
            guard let self else { return }
            guard !self.isNavigationSceneSyncSuppressed else { return }
            self.flowCoordinator.markWorkspaceEdited(features: self.features)
            let rebuiltSelectedScene = self.ensureSelectedResultSceneIsReady()
            if rebuiltSelectedScene {
                self.syncResultContentSceneGraph(for: self.selectedTab, rebuildRootScene: true)
            } else {
                self.syncSceneGraph(source: .navigation)
            }
        }

        bindInputCallbacks()
        library.syncSidebarSelection(sidebar.selectedCorpusID)
    }

    private func bindInputCallbacks() {
        stats.onSceneChange = { [weak self] in
            self?.syncVisibleResultSceneIfNeeded(.stats)
        }
        word.onSceneChange = { [weak self] in
            self?.syncVisibleResultSceneIfNeeded(.word)
        }
        compare.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        sentiment.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        plot.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        keyword.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        kwic.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        ngram.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        cluster.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        word.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        tokenize.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        topics.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        collocate.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
    }
}
