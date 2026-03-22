const SUPPORTED_IMPORT_EXTENSIONS = new Set(['.txt', '.docx', '.pdf'])
const IMPORT_HIERARCHY_SEPARATOR = ' ⟫ '

function registerLibraryIpcRoutes({
  registerSafeIpcHandler,
  app,
  fs,
  path,
  showOpenDialogForApp,
  readCorpusFile,
  inspectCorpusFilePreflight,
  addRecentDocumentIfSupported,
  getCorpusStorage,
  normalizeFilePathInput,
  normalizeIdentifier,
  normalizeTextInput,
  pathExists,
  showItemInSystemFileManager
}) {
  function getSourceTypeFromExtension(extension) {
    if (extension === '.docx') return 'docx'
    if (extension === '.pdf') return 'pdf'
    return 'txt'
  }

  async function runPreflightCheck(targetPath) {
    if (typeof inspectCorpusFilePreflight !== 'function') {
      return {
        ok: true,
        warnings: [],
        errors: []
      }
    }

    try {
      const result = await inspectCorpusFilePreflight(targetPath)
      const warnings = Array.isArray(result?.warnings)
        ? result.warnings.map(item => String(item || '').trim()).filter(Boolean)
        : []
      const errors = Array.isArray(result?.errors)
        ? result.errors.map(item => String(item || '').trim()).filter(Boolean)
        : []
      return {
        ok: result?.ok !== false && errors.length === 0,
        warnings,
        errors
      }
    } catch (error) {
      return {
        ok: false,
        warnings: [],
        errors: [String(error?.message || '导入前体检失败')]
      }
    }
  }

  function buildHierarchyFolderName(rootLabel, relativeDir, pathModule) {
    const segments = []
    const safeRootLabel = String(rootLabel || '').trim()
    if (safeRootLabel) segments.push(safeRootLabel)

    const safeRelativeDir = String(relativeDir || '').trim()
    if (safeRelativeDir) {
      for (const segment of safeRelativeDir.split(pathModule.sep)) {
        const cleanedSegment = String(segment || '').trim()
        if (cleanedSegment && cleanedSegment !== '.') segments.push(cleanedSegment)
      }
    }

    return segments.join(IMPORT_HIERARCHY_SEPARATOR)
  }

  async function collectImportEntriesFromPaths(rawInputPaths = []) {
    const collectedEntries = []
    const skippedEntries = []
    const visitedPaths = new Set()

    const pushSkippedEntry = (targetPath, reason) => {
      skippedEntries.push({
        sourcePath: String(targetPath || '').trim(),
        reason: String(reason || '已跳过')
      })
    }

    const collectSingleFile = (filePath, rootLabel = '', relativeDir = '') => {
      const extension = path.extname(filePath).toLowerCase()
      if (!SUPPORTED_IMPORT_EXTENSIONS.has(extension)) {
        pushSkippedEntry(filePath, '不支持的文件类型')
        return
      }
      collectedEntries.push({
        sourcePath: filePath,
        extension,
        rootLabel,
        relativeDir
      })
    }

    const walkDirectory = async (rootDir, currentDir, rootLabel) => {
      let entries
      try {
        entries = await fs.readdir(currentDir, { withFileTypes: true })
      } catch (error) {
        pushSkippedEntry(currentDir, error?.message || '目录读取失败')
        return
      }

      for (const entry of entries) {
        const absolutePath = path.join(currentDir, entry.name)
        if (entry.isDirectory()) {
          await walkDirectory(rootDir, absolutePath, rootLabel)
          continue
        }
        if (!entry.isFile()) continue
        const relativeDir = path.relative(rootDir, path.dirname(absolutePath))
        collectSingleFile(
          absolutePath,
          rootLabel,
          relativeDir === '.' ? '' : relativeDir
        )
      }
    }

    for (const rawInputPath of Array.isArray(rawInputPaths) ? rawInputPaths : []) {
      let normalizedInputPath = ''
      try {
        normalizedInputPath = normalizeFilePathInput(rawInputPath, { fieldName: '导入路径' })
      } catch (error) {
        pushSkippedEntry(rawInputPath, error?.message || '路径无效')
        continue
      }

      if (visitedPaths.has(normalizedInputPath)) continue
      visitedPaths.add(normalizedInputPath)

      let stats
      try {
        stats = await fs.stat(normalizedInputPath)
      } catch (error) {
        pushSkippedEntry(normalizedInputPath, error?.message || '路径不可读取')
        continue
      }

      if (stats.isDirectory()) {
        await walkDirectory(
          normalizedInputPath,
          normalizedInputPath,
          path.basename(normalizedInputPath)
        )
        continue
      }

      if (stats.isFile()) {
        collectSingleFile(normalizedInputPath, '', '')
        continue
      }

      pushSkippedEntry(normalizedInputPath, '仅支持文件或文件夹')
    }

    return {
      collectedEntries,
      skippedEntries
    }
  }

  registerSafeIpcHandler('show-saved-corpus-in-folder', async (event, corpusId) => {
    const normalizedCorpusId = normalizeIdentifier(corpusId, { fieldName: '语料 ID' })
    const record = await getCorpusStorage().findSavedCorpusRecord(normalizedCorpusId)

    if (!record) {
      return {
        success: false,
        message: '找不到该语料'
      }
    }

    return showItemInSystemFileManager(record.recordPaths.contentPath, {
      fieldName: '语料文件路径',
      missingMessage: '语料文件已不存在'
    })
  })

  registerSafeIpcHandler('show-recycle-entry-in-folder', async (event, recycleEntryId) => {
    const normalizedEntryId = normalizeIdentifier(recycleEntryId, { fieldName: '回收站条目 ID' })
    const entry = await getCorpusStorage().findRecycleEntry(normalizedEntryId)

    if (!entry || !entry.entryPaths?.recordDir) {
      return {
        success: false,
        message: '找不到该回收站条目'
      }
    }

    return showItemInSystemFileManager(entry.entryPaths.recordDir, {
      fieldName: '回收站路径',
      missingMessage: '回收站项目已不存在'
    })
  })

  registerSafeIpcHandler('open-quick-corpus', async () => {
    const result = await showOpenDialogForApp({
      properties: ['openFile'],
      filters: [{ name: '语料文件', extensions: ['txt', 'docx', 'pdf'] }]
    })

    if (result.canceled || result.filePaths.length === 0) {
      return {
        success: false,
        canceled: true,
        message: '用户取消了选择'
      }
    }

    const filePath = result.filePaths[0]
    const preflight = await runPreflightCheck(filePath)
    if (!preflight.ok) {
      return {
        success: false,
        message: preflight.errors[0] || '导入前体检未通过',
        preflightWarnings: preflight.warnings,
        preflightErrors: preflight.errors
      }
    }

    const { content, encoding } = await readCorpusFile(filePath)
    addRecentDocumentIfSupported(app, filePath, console)
    const sourceType = path.extname(filePath).toLowerCase() === '.docx'
      ? 'docx'
      : path.extname(filePath).toLowerCase() === '.pdf'
        ? 'pdf'
        : 'txt'

    return {
      success: true,
      mode: 'quick',
      filePath,
      fileName: path.basename(filePath),
      displayName: path.basename(filePath, path.extname(filePath)),
      content,
      sourceType,
      sourceEncoding: encoding,
      preflightWarnings: preflight.warnings,
      preflightWarningCount: preflight.warnings.length
    }
  })

  registerSafeIpcHandler('open-quick-corpus-at-path', async (event, filePath) => {
    const resolvedFilePath = normalizeFilePathInput(filePath, { fieldName: '语料路径' })
    if (!(await pathExists(fs, resolvedFilePath))) {
      return {
        success: false,
        message: '原始语料文件已不存在'
      }
    }

    const preflight = await runPreflightCheck(resolvedFilePath)
    if (!preflight.ok) {
      return {
        success: false,
        message: preflight.errors[0] || '导入前体检未通过',
        preflightWarnings: preflight.warnings,
        preflightErrors: preflight.errors
      }
    }

    const { content, encoding } = await readCorpusFile(resolvedFilePath)
    addRecentDocumentIfSupported(app, resolvedFilePath, console)
    const sourceType = path.extname(resolvedFilePath).toLowerCase() === '.docx'
      ? 'docx'
      : path.extname(resolvedFilePath).toLowerCase() === '.pdf'
        ? 'pdf'
        : 'txt'

    return {
      success: true,
      mode: 'quick',
      filePath: resolvedFilePath,
      fileName: path.basename(resolvedFilePath),
      displayName: path.basename(resolvedFilePath, path.extname(resolvedFilePath)),
      content,
      sourceType,
      sourceEncoding: encoding,
      preflightWarnings: preflight.warnings,
      preflightWarningCount: preflight.warnings.length
    }
  })

  registerSafeIpcHandler('import-and-save-corpus', async (event, payload = {}) => {
    const result = await showOpenDialogForApp({
      properties: ['openFile'],
      filters: [{ name: '语料文件', extensions: ['txt', 'docx', 'pdf'] }]
    })

    if (result.canceled || result.filePaths.length === 0) {
      return {
        success: false,
        canceled: true,
        message: '用户取消了选择'
      }
    }

    const sourcePath = result.filePaths[0]
    const originalName = path.basename(sourcePath)
    const originalExt = path.extname(sourcePath).toLowerCase()
    const preflight = await runPreflightCheck(sourcePath)
    if (!preflight.ok) {
      return {
        success: false,
        message: preflight.errors[0] || '导入前体检未通过',
        preflightWarnings: preflight.warnings,
        preflightErrors: preflight.errors
      }
    }

    const { content, encoding } = await readCorpusFile(sourcePath)
    addRecentDocumentIfSupported(app, sourcePath, console)
    const savedRecord = await getCorpusStorage().importCorpus({
      originalName,
      sourceType: originalExt === '.docx' ? 'docx' : originalExt === '.pdf' ? 'pdf' : 'txt',
      content,
      folderId:
        normalizeIdentifier(payload?.folderId, {
          fieldName: '文件夹 ID',
          allowEmpty: true
        }) || ''
    })

    return {
      success: true,
      mode: 'saved',
      corpusId: savedRecord.meta.id,
      filePath: savedRecord.filePath,
      fileName: savedRecord.fileName,
      displayName: savedRecord.meta.name,
      folderId: savedRecord.meta.folderId,
      folderName: savedRecord.meta.folderName,
      content,
      sourceEncoding: encoding,
      preflightWarnings: preflight.warnings,
      preflightWarningCount: preflight.warnings.length
    }
  })

  registerSafeIpcHandler('import-corpus-paths', async (event, payload = {}) => {
    const rawPaths = Array.isArray(payload?.paths) ? payload.paths : []
    if (rawPaths.length === 0) {
      return {
        success: false,
        message: '没有可导入的路径'
      }
    }

    const preserveHierarchy = payload?.preserveHierarchy !== false
    const fallbackFolderId =
      normalizeIdentifier(payload?.folderId, {
        fieldName: '文件夹 ID',
        allowEmpty: true
      }) || ''

    const { collectedEntries, skippedEntries } = await collectImportEntriesFromPaths(rawPaths)
    if (collectedEntries.length === 0) {
      return {
        success: false,
        message: skippedEntries.length > 0 ? '未找到可导入的 txt / docx / pdf 文件' : '没有可导入的语料文件',
        skippedCount: skippedEntries.length,
        skippedEntries: skippedEntries.slice(0, 20)
      }
    }

    const storage = getCorpusStorage()
    const folderSnapshot = await storage.listLibrary('all')
    const folderNameToId = new Map(
      (folderSnapshot?.folders || [])
        .map(folder => [String(folder?.name || ''), String(folder?.id || '')])
        .filter(([name, id]) => name && id)
    )

    const ensureFolderIdByName = async folderName => {
      const normalizedFolderName = String(folderName || '').trim()
      if (!normalizedFolderName) return fallbackFolderId

      const existingFolderId = folderNameToId.get(normalizedFolderName)
      if (existingFolderId) return existingFolderId

      const createResult = await storage.createFolder(normalizedFolderName)
      if (createResult?.success && createResult.folder?.id) {
        folderNameToId.set(normalizedFolderName, createResult.folder.id)
        return createResult.folder.id
      }

      const refreshedSnapshot = await storage.listLibrary('all')
      for (const folder of refreshedSnapshot?.folders || []) {
        const folderNameKey = String(folder?.name || '').trim()
        const folderIdValue = String(folder?.id || '').trim()
        if (folderNameKey && folderIdValue) {
          folderNameToId.set(folderNameKey, folderIdValue)
        }
      }
      return folderNameToId.get(normalizedFolderName) || fallbackFolderId
    }

    const importedCorpusItems = []
    const importSkippedEntries = [...skippedEntries]
    const preflightWarningEntries = []

    for (const entry of collectedEntries) {
      try {
        const sourcePath = entry.sourcePath
        const extension = path.extname(sourcePath).toLowerCase()
        const sourceType = getSourceTypeFromExtension(extension)
        const preflight = await runPreflightCheck(sourcePath)
        if (!preflight.ok) {
          importSkippedEntries.push({
            sourcePath,
            reason: preflight.errors[0] || '导入前体检未通过'
          })
          continue
        }
        if (preflight.warnings.length > 0) {
          preflightWarningEntries.push({
            sourcePath,
            warnings: preflight.warnings
          })
        }

        const { content, encoding } = await readCorpusFile(sourcePath)
        const hierarchyFolderName =
          preserveHierarchy && entry.rootLabel
            ? buildHierarchyFolderName(entry.rootLabel, entry.relativeDir, path)
            : ''
        const targetFolderId = hierarchyFolderName
          ? await ensureFolderIdByName(hierarchyFolderName)
          : fallbackFolderId

        const savedRecord = await storage.importCorpus({
          originalName: path.basename(sourcePath),
          sourceType,
          content,
          folderId: targetFolderId
        })
        addRecentDocumentIfSupported(app, sourcePath, console)
        importedCorpusItems.push({
          id: savedRecord.meta.id,
          name: savedRecord.meta.name,
          folderId: savedRecord.meta.folderId,
          folderName: savedRecord.meta.folderName,
          filePath: savedRecord.filePath,
          sourcePath,
          sourceEncoding: encoding,
          preflightWarnings: preflight.warnings
        })
      } catch (error) {
        importSkippedEntries.push({
          sourcePath: entry.sourcePath,
          reason: error?.message || '导入失败'
        })
      }
    }

    if (importedCorpusItems.length === 0) {
      return {
        success: false,
        message: '批量导入失败，没有成功导入的语料',
        skippedCount: importSkippedEntries.length,
        skippedEntries: importSkippedEntries.slice(0, 20)
      }
    }

    const openResult =
      importedCorpusItems.length === 1
        ? await storage.openCorpus(importedCorpusItems[0].id)
        : await storage.openCorpora(importedCorpusItems.map(item => item.id))

    if (!openResult?.success) {
      return {
        success: false,
        message: openResult?.message || '导入后打开语料失败',
        importedCount: importedCorpusItems.length,
        skippedCount: importSkippedEntries.length,
        skippedEntries: importSkippedEntries.slice(0, 20),
        preflightWarningEntries: preflightWarningEntries.slice(0, 20),
        preflightWarningCount: preflightWarningEntries.reduce((sum, item) => sum + item.warnings.length, 0)
      }
    }

    return {
      ...openResult,
      importedCount: importedCorpusItems.length,
      skippedCount: importSkippedEntries.length,
      skippedEntries: importSkippedEntries.slice(0, 20),
      importedItems: importedCorpusItems,
      preflightWarningEntries: preflightWarningEntries.slice(0, 20),
      preflightWarningCount: preflightWarningEntries.reduce((sum, item) => sum + item.warnings.length, 0)
    }
  })

  registerSafeIpcHandler('backup-corpus-library', async () => {
    const result = await showOpenDialogForApp({
      properties: ['openDirectory', 'createDirectory']
    })

    if (result.canceled || result.filePaths.length === 0) {
      return {
        success: false,
        canceled: true,
        message: '用户取消了备份位置选择'
      }
    }

    return getCorpusStorage().backupLibrary(result.filePaths[0])
  })

  registerSafeIpcHandler('restore-corpus-library', async () => {
    const result = await showOpenDialogForApp({
      properties: ['openDirectory']
    })

    if (result.canceled || result.filePaths.length === 0) {
      return {
        success: false,
        canceled: true,
        message: '用户取消了备份目录选择'
      }
    }

    return getCorpusStorage().restoreLibrary(result.filePaths[0])
  })

  registerSafeIpcHandler('repair-corpus-library', async () => {
    return getCorpusStorage().repairLibrary()
  })

  registerSafeIpcHandler('create-corpus-folder', async (event, folderName) => {
    return getCorpusStorage().createFolder(normalizeTextInput(folderName, { maxLength: 80 }))
  })

  registerSafeIpcHandler('rename-corpus-folder', async (event, { folderId, newName } = {}) => {
    return getCorpusStorage().renameFolder(
      normalizeIdentifier(folderId, { fieldName: '文件夹 ID' }),
      normalizeTextInput(newName, { maxLength: 80 })
    )
  })

  registerSafeIpcHandler('delete-corpus-folder', async (event, folderId) => {
    return getCorpusStorage().deleteFolder(normalizeIdentifier(folderId, { fieldName: '文件夹 ID' }))
  })

  registerSafeIpcHandler('list-saved-corpora', async (event, payload = {}) => {
    return getCorpusStorage().listLibrary(
      normalizeIdentifier(payload?.folderId, {
        fieldName: '文件夹 ID',
        allowAll: true,
        allowEmpty: true
      }) || 'all'
    )
  })

  registerSafeIpcHandler('list-searchable-corpora', async (event, payload = {}) => {
    return getCorpusStorage().listSearchableCorpora(
      normalizeIdentifier(payload?.folderId, {
        fieldName: '文件夹 ID',
        allowAll: true,
        allowEmpty: true
      }) || 'all'
    )
  })

  registerSafeIpcHandler('search-library-kwic', async (event, payload = {}) => {
    return getCorpusStorage().searchLibraryKWIC({
      folderId:
        normalizeIdentifier(payload?.folderId, {
          fieldName: '文件夹 ID',
          allowAll: true,
          allowEmpty: true
        }) || 'all',
      keyword: normalizeTextInput(payload?.keyword, { fallback: '', maxLength: 320 }),
      leftWindowSize: Number(payload?.leftWindowSize),
      rightWindowSize: Number(payload?.rightWindowSize),
      searchOptions: payload?.searchOptions && typeof payload.searchOptions === 'object'
        ? payload.searchOptions
        : {}
    })
  })

  registerSafeIpcHandler('list-recycle-bin', async () => {
    return getCorpusStorage().listRecycleBin()
  })

  registerSafeIpcHandler('restore-recycle-entry', async (event, recycleEntryId) => {
    return getCorpusStorage().restoreRecycleEntry(
      normalizeIdentifier(recycleEntryId, { fieldName: '回收站条目 ID' })
    )
  })

  registerSafeIpcHandler('purge-recycle-entry', async (event, recycleEntryId) => {
    return getCorpusStorage().purgeRecycleEntry(
      normalizeIdentifier(recycleEntryId, { fieldName: '回收站条目 ID' })
    )
  })

  registerSafeIpcHandler('open-saved-corpus', async (event, corpusId) => {
    const result = await getCorpusStorage().openCorpus(
      normalizeIdentifier(corpusId, { fieldName: '语料 ID' })
    )
    if (result?.success && result.filePath) {
      addRecentDocumentIfSupported(app, result.filePath, console)
    }
    return result
  })

  registerSafeIpcHandler('open-saved-corpora', async (event, corpusIds = []) => {
    if (!Array.isArray(corpusIds) || corpusIds.length === 0) {
      return {
        success: false,
        message: '请至少选择一条语料'
      }
    }

    const result = await getCorpusStorage().openCorpora(
      corpusIds.map(corpusId => normalizeIdentifier(corpusId, { fieldName: '语料 ID' }))
    )
    if (result?.success && Array.isArray(result.selectedItems)) {
      for (const item of result.selectedItems) {
        if (item?.filePath) {
          addRecentDocumentIfSupported(app, item.filePath, console)
        }
      }
    }
    return result
  })

  registerSafeIpcHandler('rename-saved-corpus', async (event, { corpusId, newName } = {}) => {
    return getCorpusStorage().renameCorpus(
      normalizeIdentifier(corpusId, { fieldName: '语料 ID' }),
      normalizeTextInput(newName, { maxLength: 120 })
    )
  })

  registerSafeIpcHandler('move-saved-corpus', async (event, { corpusId, targetFolderId } = {}) => {
    return getCorpusStorage().moveCorpus(
      normalizeIdentifier(corpusId, { fieldName: '语料 ID' }),
      normalizeIdentifier(targetFolderId, {
        fieldName: '目标文件夹 ID',
        allowEmpty: true
      }) || ''
    )
  })

  registerSafeIpcHandler('delete-saved-corpus', async (event, corpusId) => {
    return getCorpusStorage().deleteCorpus(normalizeIdentifier(corpusId, { fieldName: '语料 ID' }))
  })
}

module.exports = {
  registerLibraryIpcRoutes
}
