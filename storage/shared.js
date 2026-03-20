function installCorpusStorageShared(
  CorpusStorage,
  {
    path,
    fs,
    CORPUS_LIBRARY_SCHEMA_VERSION,
    DEFAULT_FOLDER_ID,
    DEFAULT_FOLDER_NAME,
    SAFE_STORAGE_ID_PATTERN
  }
) {
  Object.assign(CorpusStorage.prototype, {
    async prepareImpl() {
      const paths = this.getPaths()
      await this.ensureDirectory(paths.baseDir)
      await this.ensureDirectory(paths.foldersDir)
      await this.ensureDirectory(paths.recycleDir)
      await this.ensureDirectory(paths.recycleCorporaDir)
      await this.ensureDirectory(paths.recycleFoldersDir)
      await this.ensureCorpusLibraryManifest()
      await this.ensureDefaultFolder()
      await this.migrateLegacyFlatLibrary()
      await this.migrateLegacyFolderlessCorpora()
      await this.ensureDefaultFolder()
      return paths
    },

    getPaths() {
      return {
        baseDir: this.baseDir,
        foldersDir: path.join(this.baseDir, 'folders'),
        manifestPath: path.join(this.baseDir, 'library.json'),
        repairRootDir: path.join(this.baseDir, 'repair-quarantine'),
        recycleDir: path.join(this.baseDir, 'recycle-bin'),
        recycleCorporaDir: path.join(this.baseDir, 'recycle-bin', 'corpora'),
        recycleFoldersDir: path.join(this.baseDir, 'recycle-bin', 'folders'),
        legacyIndexPath: path.join(this.baseDir, 'index.json'),
        legacyItemsDir: path.join(this.baseDir, 'items'),
        legacyV1BackupDir: path.join(this.baseDir, 'legacy-v1'),
        legacyCorporaDir: path.join(this.baseDir, 'corpora'),
        legacyV2BackupDir: path.join(this.baseDir, 'legacy-v2')
      }
    },

    getFolderPaths(folderId) {
      const normalizedId =
        this.normalizeStorageId(folderId) === ''
          ? DEFAULT_FOLDER_ID
          : this.assertStorageId(folderId, '文件夹 ID')
      const folderDir = path.join(this.getPaths().foldersDir, normalizedId)

      return {
        folderId: normalizedId,
        folderDir,
        folderMetaPath: path.join(folderDir, 'meta.json'),
        corporaDir: path.join(folderDir, 'corpora')
      }
    },

    getCorpusRecordPaths(folderId, corpusId) {
      const folderPaths = this.getFolderPaths(folderId)
      const normalizedCorpusId = this.assertStorageId(corpusId, '语料 ID')
      const corpusDir = path.join(folderPaths.corporaDir, normalizedCorpusId)

      return {
        ...folderPaths,
        corpusId: normalizedCorpusId,
        corpusDir,
        corpusMetaPath: path.join(corpusDir, 'meta.json'),
        contentPath: path.join(corpusDir, 'content.txt')
      }
    },

    getRecycleEntryPaths(entryType, recycleEntryId) {
      const normalizedEntryId = this.assertStorageId(recycleEntryId, '回收站条目 ID')
      const recycleRootDir =
        entryType === 'folder' ? this.getPaths().recycleFoldersDir : this.getPaths().recycleCorporaDir
      const entryDir = path.join(recycleRootDir, normalizedEntryId)

      return {
        type: entryType === 'folder' ? 'folder' : 'corpus',
        recycleEntryId: normalizedEntryId,
        entryDir,
        metaPath: path.join(entryDir, 'recycle.json'),
        recordDir: path.join(entryDir, entryType === 'folder' ? 'folder' : 'record')
      }
    },

    generateCorpusId() {
      return `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    },

    generateFolderId() {
      return `folder_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    },

    generateRecycleEntryId(prefix = 'recycle') {
      return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    },

    normalizeStorageId(value) {
      return String(value ?? '').trim()
    },

    isSafeStorageId(value) {
      return SAFE_STORAGE_ID_PATTERN.test(this.normalizeStorageId(value))
    },

    assertStorageId(value, label) {
      const normalizedValue = this.normalizeStorageId(value)
      if (!this.isSafeStorageId(normalizedValue)) {
        throw new Error(`${label}格式不合法`)
      }
      return normalizedValue
    },

    normalizeRequestedFolderId(requestedFolderId, { allowAll = false, fallback = DEFAULT_FOLDER_ID } = {}) {
      const normalizedValue = this.normalizeStorageId(requestedFolderId)
      if (!normalizedValue) return fallback
      if (allowAll && normalizedValue === 'all') return 'all'
      return this.assertStorageId(normalizedValue, '文件夹 ID')
    },

    sanitizeCorpusName(name) {
      return String(name || '')
        .trim()
        .replace(/[\\/:*?"<>|]/g, '_')
        .slice(0, 120)
    },

    sanitizeFolderName(name) {
      return String(name || '')
        .trim()
        .replace(/[\\/:*?"<>|]/g, '_')
        .slice(0, 80)
    },

    normalizeSourceType(sourceType) {
      return sourceType === 'docx' ? 'docx' : sourceType === 'pdf' ? 'pdf' : 'txt'
    },

    normalizeCorpusText(text) {
      return String(text || '').replace(/\r\n/g, '\n').trim()
    },

    isValidDateString(value) {
      return typeof value === 'string' && !Number.isNaN(new Date(value).getTime())
    },

    async ensureDirectory(dirPath) {
      await fs.mkdir(dirPath, { recursive: true })
    },

    async pathExists(targetPath) {
      try {
        await fs.access(targetPath)
        return true
      } catch {
        return false
      }
    },

    async readJsonFile(filePath, fallbackValue) {
      try {
        const content = await fs.readFile(filePath, 'utf-8')
        return JSON.parse(content)
      } catch {
        return fallbackValue
      }
    },

    async writeTextFileAtomic(filePath, content) {
      await this.ensureDirectory(path.dirname(filePath))
      const tempPath = `${filePath}.${process.pid}.${Date.now()}.tmp`
      await fs.writeFile(tempPath, content, 'utf-8')
      await fs.rename(tempPath, filePath)
    },

    async writeJsonFileAtomic(filePath, data) {
      await this.writeTextFileAtomic(filePath, JSON.stringify(data, null, 2))
    },

    createTimestampLabel(date = new Date()) {
      const pad = value => String(value).padStart(2, '0')
      return [
        date.getFullYear(),
        pad(date.getMonth() + 1),
        pad(date.getDate()),
        '-',
        pad(date.getHours()),
        pad(date.getMinutes()),
        pad(date.getSeconds())
      ].join('')
    },

    isSameOrSubPath(parentPath, targetPath) {
      const relativePath = path.relative(path.resolve(parentPath), path.resolve(targetPath))
      return relativePath === '' || (!relativePath.startsWith('..') && !path.isAbsolute(relativePath))
    },

    async buildUniquePath(targetPath) {
      if (!(await this.pathExists(targetPath))) {
        return targetPath
      }

      const parsedPath = path.parse(targetPath)
      let index = 1
      while (true) {
        const nextPath = path.join(parsedPath.dir, `${parsedPath.name}-${index}${parsedPath.ext}`)
        if (!(await this.pathExists(nextPath))) {
          return nextPath
        }
        index += 1
      }
    },

    async moveEntryToQuarantine(sourcePath, quarantineRootDir, ...relativeParts) {
      const targetDir = path.join(quarantineRootDir, ...relativeParts)
      await this.ensureDirectory(targetDir)
      const targetPath = await this.buildUniquePath(path.join(targetDir, path.basename(sourcePath)))
      await fs.rename(sourcePath, targetPath)
      return targetPath
    },

    normalizeFolderMeta(rawMeta, folderId, fallbackTimestamps = {}) {
      const fallbackId = this.isSafeStorageId(folderId) ? this.normalizeStorageId(folderId) : DEFAULT_FOLDER_ID
      const normalizedId = this.isSafeStorageId(rawMeta?.id)
        ? this.normalizeStorageId(rawMeta.id)
        : fallbackId
      const createdAt = this.isValidDateString(rawMeta?.createdAt)
        ? rawMeta.createdAt
        : fallbackTimestamps.createdAt || new Date().toISOString()
      const updatedAt = this.isValidDateString(rawMeta?.updatedAt)
        ? rawMeta.updatedAt
        : fallbackTimestamps.updatedAt || createdAt
      const system = normalizedId === DEFAULT_FOLDER_ID || Boolean(rawMeta?.system)

      return {
        schemaVersion: CORPUS_LIBRARY_SCHEMA_VERSION,
        id: normalizedId,
        name:
          normalizedId === DEFAULT_FOLDER_ID
            ? DEFAULT_FOLDER_NAME
            : this.sanitizeFolderName(rawMeta?.name) || '未命名分类',
        system,
        createdAt,
        updatedAt
      }
    },

    normalizeCorpusMeta(rawMeta, corpusId, folderId, fallbackTimestamps = {}) {
      const fallbackId = this.isSafeStorageId(corpusId) ? this.normalizeStorageId(corpusId) : this.generateCorpusId()
      const fallbackFolderId = this.isSafeStorageId(folderId)
        ? this.normalizeStorageId(folderId)
        : DEFAULT_FOLDER_ID
      const normalizedId = this.isSafeStorageId(rawMeta?.id)
        ? this.normalizeStorageId(rawMeta.id)
        : fallbackId
      const normalizedFolderId = this.isSafeStorageId(rawMeta?.folderId)
        ? this.normalizeStorageId(rawMeta.folderId)
        : fallbackFolderId
      const createdAt = this.isValidDateString(rawMeta?.createdAt)
        ? rawMeta.createdAt
        : fallbackTimestamps.createdAt || new Date().toISOString()
      const updatedAt = this.isValidDateString(rawMeta?.updatedAt)
        ? rawMeta.updatedAt
        : fallbackTimestamps.updatedAt || createdAt

      return {
        schemaVersion: CORPUS_LIBRARY_SCHEMA_VERSION,
        id: normalizedId,
        folderId: normalizedFolderId,
        name: this.sanitizeCorpusName(rawMeta?.name) || '未命名语料',
        originalName: String(rawMeta?.originalName || ''),
        sourceType: this.normalizeSourceType(rawMeta?.sourceType),
        createdAt,
        updatedAt
      }
    },

    isSameFolderMeta(rawMeta, normalizedMeta) {
      return Boolean(
        rawMeta &&
          rawMeta.schemaVersion === normalizedMeta.schemaVersion &&
          rawMeta.id === normalizedMeta.id &&
          rawMeta.name === normalizedMeta.name &&
          Boolean(rawMeta.system) === normalizedMeta.system &&
          rawMeta.createdAt === normalizedMeta.createdAt &&
          rawMeta.updatedAt === normalizedMeta.updatedAt
      )
    },

    isSameCorpusMeta(rawMeta, normalizedMeta) {
      return Boolean(
        rawMeta &&
          rawMeta.schemaVersion === normalizedMeta.schemaVersion &&
          rawMeta.id === normalizedMeta.id &&
          rawMeta.folderId === normalizedMeta.folderId &&
          rawMeta.name === normalizedMeta.name &&
          rawMeta.originalName === normalizedMeta.originalName &&
          rawMeta.sourceType === normalizedMeta.sourceType &&
          rawMeta.createdAt === normalizedMeta.createdAt &&
          rawMeta.updatedAt === normalizedMeta.updatedAt
      )
    },

    async ensureCorpusLibraryManifest(overrides = {}) {
      const paths = this.getPaths()
      const existing = await this.readJsonFile(paths.manifestPath, null)
      const nextManifest = {
        schemaVersion: CORPUS_LIBRARY_SCHEMA_VERSION,
        layout: 'foldered-corpora',
        defaultFolderId: DEFAULT_FOLDER_ID,
        createdAt: existing?.createdAt || new Date().toISOString(),
        legacyV1MigratedAt: existing?.legacyV1MigratedAt || null,
        legacyV1ArchiveDir: existing?.legacyV1ArchiveDir || null,
        legacyV2MigratedAt: existing?.legacyV2MigratedAt || null,
        legacyV2ArchiveDir: existing?.legacyV2ArchiveDir || null,
        ...overrides
      }

      if (!existing || JSON.stringify(existing) !== JSON.stringify(nextManifest)) {
        await this.writeJsonFileAtomic(paths.manifestPath, nextManifest)
      }

      return nextManifest
    },

    async readSavedFolderMeta(folderId) {
      const folderPaths = this.getFolderPaths(folderId)

      if (!(await this.pathExists(folderPaths.folderDir))) {
        if (folderPaths.folderId === DEFAULT_FOLDER_ID) {
          await this.ensureDirectory(folderPaths.folderDir)
          await this.ensureDirectory(folderPaths.corporaDir)
        } else {
          return null
        }
      }

      await this.ensureDirectory(folderPaths.corporaDir)
      const stats = await fs.stat(folderPaths.folderDir)
      const rawMeta = await this.readJsonFile(folderPaths.folderMetaPath, null)
      const normalizedMeta = this.normalizeFolderMeta(
        rawMeta || { id: folderPaths.folderId },
        folderPaths.folderId,
        {
          createdAt: stats.birthtime.toISOString(),
          updatedAt: stats.mtime.toISOString()
        }
      )

      if (!rawMeta || !this.isSameFolderMeta(rawMeta, normalizedMeta)) {
        await this.writeJsonFileAtomic(folderPaths.folderMetaPath, normalizedMeta)
      }

      return normalizedMeta
    },

    async ensureFolderMeta(folderId, rawMeta = null) {
      const folderPaths = this.getFolderPaths(folderId)
      await this.ensureDirectory(folderPaths.folderDir)
      await this.ensureDirectory(folderPaths.corporaDir)

      if (rawMeta) {
        const normalizedMeta = this.normalizeFolderMeta(rawMeta, folderPaths.folderId)
        await this.writeJsonFileAtomic(folderPaths.folderMetaPath, normalizedMeta)
        return normalizedMeta
      }

      return this.readSavedFolderMeta(folderPaths.folderId)
    },

    async ensureDefaultFolder() {
      return this.ensureFolderMeta(DEFAULT_FOLDER_ID, {
        id: DEFAULT_FOLDER_ID,
        name: DEFAULT_FOLDER_NAME,
        system: true
      })
    },

    async touchFolderUpdatedAt(folderId, timestamp = new Date().toISOString()) {
      const folderMeta = await this.readSavedFolderMeta(folderId)

      if (!folderMeta || folderMeta.updatedAt === timestamp) {
        return folderMeta
      }

      const nextFolderMeta = {
        ...folderMeta,
        updatedAt: timestamp
      }
      const folderPaths = this.getFolderPaths(folderId)
      await this.writeJsonFileAtomic(folderPaths.folderMetaPath, nextFolderMeta)
      return nextFolderMeta
    },

    async getRealFolderMetas() {
      const paths = this.getPaths()
      await this.ensureDefaultFolder()
      const folderEntries = await fs.readdir(paths.foldersDir, { withFileTypes: true })
      const folders = []

      for (const entry of folderEntries) {
        if (!entry.isDirectory() || !this.isSafeStorageId(entry.name)) {
          continue
        }

        const folderMeta = await this.readSavedFolderMeta(entry.name)
        if (folderMeta) {
          folders.push(folderMeta)
        }
      }

      return folders.sort((a, b) => {
        if (a.id === DEFAULT_FOLDER_ID) return -1
        if (b.id === DEFAULT_FOLDER_ID) return 1
        const byUpdatedAt = new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
        if (byUpdatedAt !== 0) return byUpdatedAt
        return a.name.localeCompare(b.name, 'zh-CN')
      })
    },

    decorateCorpusItem(meta, folderMeta) {
      return {
        ...meta,
        folderName: folderMeta.name,
        isDefaultFolder: folderMeta.id === DEFAULT_FOLDER_ID
      }
    },

    async readSavedCorpusMeta(folderId, corpusId) {
      const recordPaths = this.getCorpusRecordPaths(folderId, corpusId)
      const rawMeta = await this.readJsonFile(recordPaths.corpusMetaPath, null)

      if (rawMeta) {
        const normalizedMeta = this.normalizeCorpusMeta(rawMeta, corpusId, folderId)

        if (!this.isSameCorpusMeta(rawMeta, normalizedMeta)) {
          await this.writeJsonFileAtomic(recordPaths.corpusMetaPath, normalizedMeta)
        }

        return normalizedMeta
      }

      if (!(await this.pathExists(recordPaths.contentPath))) {
        return null
      }

      const stats = await fs.stat(recordPaths.contentPath)
      const recoveredMeta = this.normalizeCorpusMeta(
        {
          id: corpusId,
          folderId,
          name: this.sanitizeCorpusName(corpusId) || '未命名语料',
          originalName: `${corpusId}.txt`,
          sourceType: 'txt',
          createdAt: stats.birthtime.toISOString(),
          updatedAt: stats.mtime.toISOString()
        },
        corpusId,
        folderId,
        {
          createdAt: stats.birthtime.toISOString(),
          updatedAt: stats.mtime.toISOString()
        }
      )

      await this.writeJsonFileAtomic(recordPaths.corpusMetaPath, recoveredMeta)
      return recoveredMeta
    },

    async writeSavedCorpusRecord({ folderId, corpusId, rawMeta, content, fallbackTimestamps = {} }) {
      const folderMeta = (await this.readSavedFolderMeta(folderId)) || (await this.ensureDefaultFolder())
      const recordPaths = this.getCorpusRecordPaths(folderMeta.id, corpusId)
      const normalizedContent = this.normalizeCorpusText(content)
      const normalizedMeta = this.normalizeCorpusMeta(
        {
          ...rawMeta,
          id: corpusId,
          folderId: folderMeta.id
        },
        corpusId,
        folderMeta.id,
        fallbackTimestamps
      )

      await this.ensureDirectory(recordPaths.corpusDir)
      await this.writeTextFileAtomic(recordPaths.contentPath, normalizedContent)
      await this.writeJsonFileAtomic(recordPaths.corpusMetaPath, normalizedMeta)
      await this.touchFolderUpdatedAt(folderMeta.id, normalizedMeta.updatedAt)

      return {
        meta: normalizedMeta,
        folder: folderMeta,
        recordPaths
      }
    },

    async listSavedCorpusItems(selectedFolderId = 'all') {
      const folders = await this.getRealFolderMetas()
      const items = []

      for (const folder of folders) {
        const folderPaths = this.getFolderPaths(folder.id)

        if (!(await this.pathExists(folderPaths.corporaDir))) {
          continue
        }

        const corpusEntries = await fs.readdir(folderPaths.corporaDir, { withFileTypes: true })
        for (const entry of corpusEntries) {
          if (!entry.isDirectory() || !this.isSafeStorageId(entry.name)) {
            continue
          }

          const recordPaths = this.getCorpusRecordPaths(folder.id, entry.name)
          if (!(await this.pathExists(recordPaths.contentPath))) {
            continue
          }

          const item = await this.readSavedCorpusMeta(folder.id, entry.name)
          if (item) {
            items.push(this.decorateCorpusItem(item, folder))
          }
        }
      }

      items.sort((a, b) => {
        const byUpdatedAt = new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
        if (byUpdatedAt !== 0) return byUpdatedAt
        return a.name.localeCompare(b.name, 'zh-CN')
      })

      if (selectedFolderId && selectedFolderId !== 'all') {
        return items.filter(item => item.folderId === selectedFolderId)
      }

      return items
    },

    async findSavedCorpusRecord(corpusId) {
      const normalizedId = this.normalizeStorageId(corpusId)

      if (!this.isSafeStorageId(normalizedId)) {
        return null
      }

      const folders = await this.getRealFolderMetas()
      for (const folder of folders) {
        const recordPaths = this.getCorpusRecordPaths(folder.id, normalizedId)
        if (!(await this.pathExists(recordPaths.corpusDir))) {
          continue
        }

        const meta = await this.readSavedCorpusMeta(folder.id, normalizedId)
        if (meta) {
          return {
            folder,
            meta,
            item: this.decorateCorpusItem(meta, folder),
            recordPaths
          }
        }
      }

      return null
    },

    async resolveFolderMeta(requestedFolderId) {
      const normalizedFolderId = this.normalizeRequestedFolderId(requestedFolderId, {
        fallback: DEFAULT_FOLDER_ID
      })
      return (await this.readSavedFolderMeta(normalizedFolderId)) || this.ensureDefaultFolder()
    },

    async buildCorpusLibrarySnapshot(requestedFolderId = 'all') {
      await this.prepare()
      const normalizedRequestedFolderId = this.normalizeRequestedFolderId(requestedFolderId, {
        allowAll: true,
        fallback: 'all'
      })
      const allItems = await this.listSavedCorpusItems('all')
      const counts = {}

      for (const item of allItems) {
        counts[item.folderId] = (counts[item.folderId] || 0) + 1
      }

      const folders = (await this.getRealFolderMetas()).map(folder => ({
        ...folder,
        itemCount: counts[folder.id] || 0,
        canRename: !folder.system,
        canDelete: !folder.system
      }))

      const folderExists =
        normalizedRequestedFolderId === 'all' || folders.some(folder => folder.id === normalizedRequestedFolderId)
      const selectedFolderId = folderExists ? normalizedRequestedFolderId : DEFAULT_FOLDER_ID
      const items =
        selectedFolderId === 'all'
          ? allItems
          : allItems.filter(item => item.folderId === selectedFolderId)

      return {
        selectedFolderId,
        folders,
        items,
        totalCount: allItems.length
      }
    }
  })
}

module.exports = {
  installCorpusStorageShared
}
