function createLibraryBridge({
  ipcClient,
  normalizeBoolean,
  normalizeIdentifier,
  normalizeIdentifierList,
  normalizeTableRows,
  normalizeTextInput
}) {
  return {
    saveTableFile: (defaultBaseName, rows) =>
      ipcClient.invoke('save-table-file', {
        defaultBaseName: normalizeTextInput(defaultBaseName, 120),
        rows: normalizeTableRows(rows)
      }),

    openQuickCorpus: () =>
      ipcClient.invoke('open-quick-corpus'),

    openQuickCorpusAtPath: filePath =>
      ipcClient.invoke('open-quick-corpus-at-path', normalizeTextInput(filePath, 4096)),

    importAndSaveCorpus: folderId =>
      ipcClient.invoke('import-and-save-corpus', {
        folderId: normalizeIdentifier(folderId, { allowEmpty: true })
      }),

    importCorpusPaths: (paths, { folderId = '', preserveHierarchy = true } = {}) =>
      ipcClient.invoke('import-corpus-paths', {
        paths: Array.isArray(paths)
          ? paths
              .map(item => normalizeTextInput(item, 4096))
              .filter(Boolean)
              .slice(0, 500)
          : [],
        folderId: normalizeIdentifier(folderId, { allowEmpty: true }),
        preserveHierarchy: normalizeBoolean(preserveHierarchy)
      }),

    backupCorpusLibrary: () =>
      ipcClient.invoke('backup-corpus-library'),

    restoreCorpusLibrary: () =>
      ipcClient.invoke('restore-corpus-library'),

    repairCorpusLibrary: () =>
      ipcClient.invoke('repair-corpus-library'),

    listSavedCorpora: folderId =>
      ipcClient.invoke('list-saved-corpora', {
        folderId: normalizeIdentifier(folderId, { allowAll: true, allowEmpty: true })
      }),

    listSearchableCorpora: folderId =>
      ipcClient.invoke('list-searchable-corpora', {
        folderId: normalizeIdentifier(folderId, { allowAll: true, allowEmpty: true })
      }),

    searchLibraryKWIC: ({ folderId = 'all', keyword = '', leftWindowSize = 5, rightWindowSize = 5, searchOptions = {} } = {}) =>
      ipcClient.invoke('search-library-kwic', {
        folderId: normalizeIdentifier(folderId, { allowAll: true, allowEmpty: true }) || 'all',
        keyword: normalizeTextInput(keyword, 320),
        leftWindowSize: Number(leftWindowSize),
        rightWindowSize: Number(rightWindowSize),
        searchOptions: searchOptions && typeof searchOptions === 'object'
          ? {
              words: normalizeBoolean(searchOptions.words),
              caseSensitive: normalizeBoolean(searchOptions.caseSensitive ?? searchOptions.case),
              regex: normalizeBoolean(searchOptions.regex)
            }
          : {}
      }),

    listRecycleBin: () =>
      ipcClient.invoke('list-recycle-bin'),

    restoreRecycleEntry: recycleEntryId =>
      ipcClient.invoke('restore-recycle-entry', normalizeIdentifier(recycleEntryId)),

    purgeRecycleEntry: recycleEntryId =>
      ipcClient.invoke('purge-recycle-entry', normalizeIdentifier(recycleEntryId)),

    createCorpusFolder: folderName =>
      ipcClient.invoke('create-corpus-folder', normalizeTextInput(folderName, 80)),

    renameCorpusFolder: (folderId, newName) =>
      ipcClient.invoke('rename-corpus-folder', {
        folderId: normalizeIdentifier(folderId),
        newName: normalizeTextInput(newName, 80)
      }),

    deleteCorpusFolder: folderId =>
      ipcClient.invoke('delete-corpus-folder', normalizeIdentifier(folderId)),

    showSavedCorpusInFolder: corpusId =>
      ipcClient.invoke('show-saved-corpus-in-folder', normalizeIdentifier(corpusId)),

    showRecycleEntryInFolder: recycleEntryId =>
      ipcClient.invoke('show-recycle-entry-in-folder', normalizeIdentifier(recycleEntryId)),

    openSavedCorpus: corpusId =>
      ipcClient.invoke('open-saved-corpus', normalizeIdentifier(corpusId)),

    openSavedCorpora: corpusIds =>
      ipcClient.invoke('open-saved-corpora', normalizeIdentifierList(corpusIds)),

    renameSavedCorpus: (corpusId, newName) =>
      ipcClient.invoke('rename-saved-corpus', {
        corpusId: normalizeIdentifier(corpusId),
        newName: normalizeTextInput(newName, 120)
      }),

    moveSavedCorpus: (corpusId, targetFolderId) =>
      ipcClient.invoke('move-saved-corpus', {
        corpusId: normalizeIdentifier(corpusId),
        targetFolderId: normalizeIdentifier(targetFolderId, { allowEmpty: true })
      }),

    deleteSavedCorpus: corpusId =>
      ipcClient.invoke('delete-saved-corpus', normalizeIdentifier(corpusId))
  }
}

module.exports = {
  createLibraryBridge
}
