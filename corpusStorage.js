const path = require('path')
const fs = require('fs/promises')

const CORPUS_LIBRARY_SCHEMA_VERSION = 3
const DEFAULT_FOLDER_ID = 'uncategorized'
const DEFAULT_FOLDER_NAME = '未分类'
const SAFE_STORAGE_ID_PATTERN = /^[A-Za-z0-9_-]{1,160}$/

class CorpusStorage {
  constructor(baseDir) {
    this.baseDir = baseDir
    this.preparePromise = null
  }

  async prepare() {
    if (this.preparePromise) {
      return this.preparePromise
    }

    this.preparePromise = this.prepareImpl().catch(error => {
      this.preparePromise = null
      throw error
    })

    return this.preparePromise
  }

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
  }

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
  }

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
  }

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
  }

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
  }

  generateCorpusId() {
    return `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
  }

  generateFolderId() {
    return `folder_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
  }

  generateRecycleEntryId(prefix = 'recycle') {
    return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
  }

  normalizeStorageId(value) {
    return String(value ?? '').trim()
  }

  isSafeStorageId(value) {
    return SAFE_STORAGE_ID_PATTERN.test(this.normalizeStorageId(value))
  }

  assertStorageId(value, label) {
    const normalizedValue = this.normalizeStorageId(value)
    if (!this.isSafeStorageId(normalizedValue)) {
      throw new Error(`${label}格式不合法`)
    }
    return normalizedValue
  }

  normalizeRequestedFolderId(requestedFolderId, { allowAll = false, fallback = DEFAULT_FOLDER_ID } = {}) {
    const normalizedValue = this.normalizeStorageId(requestedFolderId)
    if (!normalizedValue) return fallback
    if (allowAll && normalizedValue === 'all') return 'all'
    return this.assertStorageId(normalizedValue, '文件夹 ID')
  }

  sanitizeCorpusName(name) {
    return String(name || '')
      .trim()
      .replace(/[\\/:*?"<>|]/g, '_')
      .slice(0, 120)
  }

  sanitizeFolderName(name) {
    return String(name || '')
      .trim()
      .replace(/[\\/:*?"<>|]/g, '_')
      .slice(0, 80)
  }

  normalizeSourceType(sourceType) {
    return sourceType === 'docx' ? 'docx' : sourceType === 'pdf' ? 'pdf' : 'txt'
  }

  normalizeCorpusText(text) {
    return String(text || '').replace(/\r\n/g, '\n').trim()
  }

  isValidDateString(value) {
    return typeof value === 'string' && !Number.isNaN(new Date(value).getTime())
  }

  async ensureDirectory(dirPath) {
    await fs.mkdir(dirPath, { recursive: true })
  }

  async pathExists(targetPath) {
    try {
      await fs.access(targetPath)
      return true
    } catch (error) {
      return false
    }
  }

  async readJsonFile(filePath, fallbackValue) {
    try {
      const content = await fs.readFile(filePath, 'utf-8')
      return JSON.parse(content)
    } catch (error) {
      return fallbackValue
    }
  }

  async writeTextFileAtomic(filePath, content) {
    await this.ensureDirectory(path.dirname(filePath))
    const tempPath = `${filePath}.${process.pid}.${Date.now()}.tmp`
    await fs.writeFile(tempPath, content, 'utf-8')
    await fs.rename(tempPath, filePath)
  }

  async writeJsonFileAtomic(filePath, data) {
    await this.writeTextFileAtomic(filePath, JSON.stringify(data, null, 2))
  }

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
  }

  isSameOrSubPath(parentPath, targetPath) {
    const relativePath = path.relative(path.resolve(parentPath), path.resolve(targetPath))
    return relativePath === '' || (!relativePath.startsWith('..') && !path.isAbsolute(relativePath))
  }

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
  }

  async moveEntryToQuarantine(sourcePath, quarantineRootDir, ...relativeParts) {
    const targetDir = path.join(quarantineRootDir, ...relativeParts)
    await this.ensureDirectory(targetDir)
    const targetPath = await this.buildUniquePath(path.join(targetDir, path.basename(sourcePath)))
    await fs.rename(sourcePath, targetPath)
    return targetPath
  }

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
  }

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
  }

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
  }

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
  }

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
  }

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
  }

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
  }

  async ensureDefaultFolder() {
    return this.ensureFolderMeta(DEFAULT_FOLDER_ID, {
      id: DEFAULT_FOLDER_ID,
      name: DEFAULT_FOLDER_NAME,
      system: true
    })
  }

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
  }

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
  }

  decorateCorpusItem(meta, folderMeta) {
    return {
      ...meta,
      folderName: folderMeta.name,
      isDefaultFolder: folderMeta.id === DEFAULT_FOLDER_ID
    }
  }

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
  }

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
  }

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
  }

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
  }

  async archiveLegacyFlatLibrary() {
    const paths = this.getPaths()
    const hasLegacyIndex = await this.pathExists(paths.legacyIndexPath)
    const hasLegacyItems = await this.pathExists(paths.legacyItemsDir)

    if (!hasLegacyIndex && !hasLegacyItems) {
      return null
    }

    let archiveDir = paths.legacyV1BackupDir
    if (await this.pathExists(archiveDir)) {
      archiveDir = path.join(paths.baseDir, `legacy-v1-${Date.now()}`)
    }

    await this.ensureDirectory(archiveDir)

    if (hasLegacyIndex) {
      await fs.rename(paths.legacyIndexPath, path.join(archiveDir, 'index.json'))
    }

    if (hasLegacyItems) {
      await fs.rename(paths.legacyItemsDir, path.join(archiveDir, 'items'))
    }

    return archiveDir
  }

  async archiveLegacyFolderlessCorpora() {
    const paths = this.getPaths()
    if (!(await this.pathExists(paths.legacyCorporaDir))) {
      return null
    }

    let archiveDir = paths.legacyV2BackupDir
    if (await this.pathExists(archiveDir)) {
      archiveDir = path.join(paths.baseDir, `legacy-v2-${Date.now()}`)
    }

    await this.ensureDirectory(archiveDir)
    await fs.rename(paths.legacyCorporaDir, path.join(archiveDir, 'corpora'))
    return archiveDir
  }

  async migrateLegacyIndexedCorpus(legacyItem, migratedIds, migratedLegacyFiles) {
    const paths = this.getPaths()
    const preferredId = this.isSafeStorageId(legacyItem?.id)
      ? this.normalizeStorageId(legacyItem.id)
      : this.generateCorpusId()
    const existingRecord = await this.findSavedCorpusRecord(preferredId)

    if (existingRecord) {
      migratedIds.add(preferredId)
      return
    }

    const legacyFileName =
      typeof legacyItem?.fileName === 'string' && legacyItem.fileName
        ? legacyItem.fileName
        : `${preferredId}.txt`
    const legacyContentPath = path.join(paths.legacyItemsDir, legacyFileName)

    if (!(await this.pathExists(legacyContentPath))) {
      return
    }

    const content = await fs.readFile(legacyContentPath, 'utf-8')
    await this.writeSavedCorpusRecord({
      folderId: DEFAULT_FOLDER_ID,
      corpusId: preferredId,
      rawMeta: {
        ...legacyItem,
        id: preferredId,
        folderId: DEFAULT_FOLDER_ID
      },
      content
    })

    migratedIds.add(preferredId)
    migratedLegacyFiles.add(legacyContentPath)
  }

  async migrateLegacyOrphanCorpus(legacyContentPath, migratedIds, migratedLegacyFiles) {
    if (migratedLegacyFiles.has(legacyContentPath)) {
      return
    }

    const fileName = path.basename(legacyContentPath)
    const rawBaseId = path.basename(fileName, path.extname(fileName)).trim()
    const baseId = this.isSafeStorageId(rawBaseId) ? rawBaseId : this.generateCorpusId()

    if (migratedIds.has(baseId) || (await this.findSavedCorpusRecord(baseId))) {
      migratedLegacyFiles.add(legacyContentPath)
      return
    }

    const stats = await fs.stat(legacyContentPath)
    const content = await fs.readFile(legacyContentPath, 'utf-8')
    await this.writeSavedCorpusRecord({
      folderId: DEFAULT_FOLDER_ID,
      corpusId: baseId,
      rawMeta: {
        id: baseId,
        folderId: DEFAULT_FOLDER_ID,
        name: this.sanitizeCorpusName(baseId) || '未命名语料',
        originalName: fileName,
        sourceType: 'txt',
        createdAt: stats.birthtime.toISOString(),
        updatedAt: stats.mtime.toISOString()
      },
      content,
      fallbackTimestamps: {
        createdAt: stats.birthtime.toISOString(),
        updatedAt: stats.mtime.toISOString()
      }
    })

    migratedIds.add(baseId)
    migratedLegacyFiles.add(legacyContentPath)
  }

  async migrateLegacyFlatLibrary() {
    const paths = this.getPaths()
    const hasLegacyIndex = await this.pathExists(paths.legacyIndexPath)
    const hasLegacyItems = await this.pathExists(paths.legacyItemsDir)

    if (!hasLegacyIndex && !hasLegacyItems) {
      return
    }

    const legacyIndexData = await this.readJsonFile(paths.legacyIndexPath, [])
    const legacyItems = Array.isArray(legacyIndexData) ? legacyIndexData : []
    const migratedIds = new Set()
    const migratedLegacyFiles = new Set()

    for (const legacyItem of legacyItems) {
      await this.migrateLegacyIndexedCorpus(legacyItem, migratedIds, migratedLegacyFiles)
    }

    if (hasLegacyItems) {
      const orphanFiles = (await fs.readdir(paths.legacyItemsDir, { withFileTypes: true }))
        .filter(entry => entry.isFile() && path.extname(entry.name).toLowerCase() === '.txt')
        .map(entry => path.join(paths.legacyItemsDir, entry.name))

      for (const legacyContentPath of orphanFiles) {
        await this.migrateLegacyOrphanCorpus(legacyContentPath, migratedIds, migratedLegacyFiles)
      }
    }

    const archiveDir = await this.archiveLegacyFlatLibrary()
    await this.ensureCorpusLibraryManifest({
      legacyV1MigratedAt: new Date().toISOString(),
      legacyV1ArchiveDir: archiveDir
    })
  }

  async migrateLegacyFolderlessCorpora() {
    const paths = this.getPaths()
    if (!(await this.pathExists(paths.legacyCorporaDir))) {
      return
    }

    const corpusEntries = await fs.readdir(paths.legacyCorporaDir, { withFileTypes: true })

    for (const entry of corpusEntries) {
      if (!entry.isDirectory()) {
        continue
      }

      const corpusId = this.isSafeStorageId(entry.name) ? entry.name : this.generateCorpusId()
      const legacyRecordDir = path.join(paths.legacyCorporaDir, entry.name)
      const legacyMetaPath = path.join(legacyRecordDir, 'meta.json')
      const legacyContentPath = path.join(legacyRecordDir, 'content.txt')

      if (!(await this.pathExists(legacyContentPath)) || (await this.findSavedCorpusRecord(corpusId))) {
        continue
      }

      const rawMeta = await this.readJsonFile(legacyMetaPath, null)
      const stats = await fs.stat(legacyContentPath)
      const content = await fs.readFile(legacyContentPath, 'utf-8')

      await this.writeSavedCorpusRecord({
        folderId: DEFAULT_FOLDER_ID,
        corpusId,
        rawMeta: {
          ...rawMeta,
          id: corpusId,
          folderId: DEFAULT_FOLDER_ID
        },
        content,
        fallbackTimestamps: {
          createdAt: stats.birthtime.toISOString(),
          updatedAt: stats.mtime.toISOString()
        }
      })
    }

    const archiveDir = await this.archiveLegacyFolderlessCorpora()
    await this.ensureCorpusLibraryManifest({
      legacyV2MigratedAt: new Date().toISOString(),
      legacyV2ArchiveDir: archiveDir
    })
  }

  async resolveFolderMeta(requestedFolderId) {
    const normalizedFolderId = this.normalizeRequestedFolderId(requestedFolderId, {
      fallback: DEFAULT_FOLDER_ID
    })
    return (await this.readSavedFolderMeta(normalizedFolderId)) || this.ensureDefaultFolder()
  }

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

  buildRecycleCorpusEntry(rawMeta) {
    const item = rawMeta?.item || {}
    return {
      recycleEntryId: this.isSafeStorageId(rawMeta?.recycleEntryId) ? this.normalizeStorageId(rawMeta.recycleEntryId) : '',
      type: 'corpus',
      deletedAt: this.isValidDateString(rawMeta?.deletedAt) ? rawMeta.deletedAt : new Date(0).toISOString(),
      name: this.sanitizeCorpusName(item.name) || '未命名语料',
      originalName: String(item.originalName || ''),
      originalFolderId: this.isSafeStorageId(rawMeta?.originalFolderId)
        ? this.normalizeStorageId(rawMeta.originalFolderId)
        : DEFAULT_FOLDER_ID,
      originalFolderName: String(rawMeta?.originalFolderName || item.folderName || DEFAULT_FOLDER_NAME),
      sourceType: this.normalizeSourceType(item.sourceType),
      item
    }
  }

  buildRecycleFolderEntry(rawMeta) {
    const folder = rawMeta?.folder || {}
    const itemCount = Number(rawMeta?.itemCount)
    return {
      recycleEntryId: this.isSafeStorageId(rawMeta?.recycleEntryId) ? this.normalizeStorageId(rawMeta.recycleEntryId) : '',
      type: 'folder',
      deletedAt: this.isValidDateString(rawMeta?.deletedAt) ? rawMeta.deletedAt : new Date(0).toISOString(),
      name: this.sanitizeFolderName(folder.name) || '未命名分类',
      originalFolderId: this.isSafeStorageId(folder.id) ? this.normalizeStorageId(folder.id) : this.generateFolderId(),
      itemCount: Number.isFinite(itemCount) && itemCount >= 0 ? itemCount : 0,
      folder
    }
  }

  async listRecycleEntriesByType(entryType) {
    const rootDir =
      entryType === 'folder' ? this.getPaths().recycleFoldersDir : this.getPaths().recycleCorporaDir
    const entries = []

    if (!(await this.pathExists(rootDir))) {
      return entries
    }

    const dirEntries = await fs.readdir(rootDir, { withFileTypes: true })
    for (const dirEntry of dirEntries) {
      if (!dirEntry.isDirectory() || !this.isSafeStorageId(dirEntry.name)) {
        continue
      }

      const entryPaths = this.getRecycleEntryPaths(entryType, dirEntry.name)
      const rawMeta = await this.readJsonFile(entryPaths.metaPath, null)
      if (!rawMeta || !(await this.pathExists(entryPaths.recordDir))) {
        continue
      }

      entries.push(
        entryType === 'folder' ? this.buildRecycleFolderEntry(rawMeta) : this.buildRecycleCorpusEntry(rawMeta)
      )
    }

    return entries
  }

  async listRecycleBin() {
    await this.prepare()
    const folderEntries = await this.listRecycleEntriesByType('folder')
    const corpusEntries = await this.listRecycleEntriesByType('corpus')
    const entries = [...folderEntries, ...corpusEntries].sort((left, right) => {
      const byDeletedAt = new Date(right.deletedAt).getTime() - new Date(left.deletedAt).getTime()
      if (byDeletedAt !== 0) return byDeletedAt
      return left.name.localeCompare(right.name, 'zh-CN')
    })

    return {
      success: true,
      entries,
      folderCount: folderEntries.length,
      corpusCount: corpusEntries.length,
      totalCount: entries.length
    }
  }

  async findRecycleEntry(recycleEntryId) {
    const normalizedEntryId = this.assertStorageId(recycleEntryId, '回收站条目 ID')

    for (const entryType of ['corpus', 'folder']) {
      const entryPaths = this.getRecycleEntryPaths(entryType, normalizedEntryId)
      if (!(await this.pathExists(entryPaths.entryDir))) {
        continue
      }

      const rawMeta = await this.readJsonFile(entryPaths.metaPath, null)
      if (!rawMeta) {
        return {
          type: entryType,
          rawMeta: null,
          entryPaths
        }
      }

      return {
        type: entryType,
        rawMeta,
        entryPaths
      }
    }

    return null
  }

  async backupLibrary(destinationRootDir) {
    await this.prepare()
    const normalizedDestinationRoot = String(destinationRootDir || '').trim()

    if (!normalizedDestinationRoot) {
      return {
        success: false,
        message: '请选择备份位置'
      }
    }

    const resolvedDestinationRoot = path.resolve(normalizedDestinationRoot)
    if (this.isSameOrSubPath(this.baseDir, resolvedDestinationRoot)) {
      return {
        success: false,
        message: '备份位置不能放在当前语料库目录内部'
      }
    }

    await this.ensureDirectory(resolvedDestinationRoot)
    const snapshot = await this.buildCorpusLibrarySnapshot('all')
    const backupDir = await this.buildUniquePath(
      path.join(resolvedDestinationRoot, `corpus-library-backup-${this.createTimestampLabel()}`)
    )

    await fs.cp(this.baseDir, backupDir, {
      recursive: true,
      errorOnExist: true,
      force: false
    })

    return {
      success: true,
      backupDir,
      folderCount: snapshot.folders.length,
      corpusCount: snapshot.totalCount,
      createdAt: new Date().toISOString()
    }
  }

  async restoreLibrary(sourceBackupDir) {
    await this.prepare()
    const normalizedSourceDir = String(sourceBackupDir || '').trim()

    if (!normalizedSourceDir) {
      return {
        success: false,
        message: '请选择备份目录'
      }
    }

    const resolvedSourceDir = path.resolve(normalizedSourceDir)
    const resolvedBaseDir = path.resolve(this.baseDir)

    if (!(await this.pathExists(resolvedSourceDir))) {
      return {
        success: false,
        message: '所选备份目录不存在'
      }
    }

    if (
      this.isSameOrSubPath(resolvedBaseDir, resolvedSourceDir) ||
      this.isSameOrSubPath(resolvedSourceDir, resolvedBaseDir)
    ) {
      return {
        success: false,
        message: '恢复目录不能是当前语料库目录，或其内部目录'
      }
    }

    const sourceManifestPath = path.join(resolvedSourceDir, 'library.json')
    if (!(await this.pathExists(sourceManifestPath))) {
      return {
        success: false,
        message: '所选目录不是有效的语料库备份'
      }
    }

    const workingRootDir = path.dirname(resolvedBaseDir)
    const timestampLabel = this.createTimestampLabel()
    const stagingDir = await this.buildUniquePath(path.join(workingRootDir, `.corpus-library-restore-${timestampLabel}`))
    const rollbackDir = await this.buildUniquePath(path.join(workingRootDir, `corpus-library-before-restore-${timestampLabel}`))

    try {
      await fs.cp(resolvedSourceDir, stagingDir, {
        recursive: true,
        errorOnExist: true,
        force: false
      })

      const stagedStorage = new CorpusStorage(stagingDir)
      const stagedSnapshot = await stagedStorage.buildCorpusLibrarySnapshot('all')

      await fs.rename(resolvedBaseDir, rollbackDir)
      try {
        await fs.rename(stagingDir, resolvedBaseDir)
      } catch (error) {
        await fs.rename(rollbackDir, resolvedBaseDir).catch(() => {})
        throw error
      }

      this.preparePromise = null
      await this.prepare()

      return {
        success: true,
        restoredFromDir: resolvedSourceDir,
        previousLibraryBackupDir: rollbackDir,
        folderCount: stagedSnapshot.folders.length,
        corpusCount: stagedSnapshot.totalCount,
        restoredAt: new Date().toISOString()
      }
    } catch (error) {
      if (await this.pathExists(stagingDir)) {
        await fs.rm(stagingDir, { recursive: true, force: true }).catch(() => {})
      }

      return {
        success: false,
        message: error && error.message ? error.message : '恢复语料库失败'
      }
    }
  }

  async repairLibrary() {
    await this.prepare()
    const paths = this.getPaths()
    const summary = {
      repairedManifest: false,
      repairedFolders: 0,
      repairedCorpora: 0,
      recoveredCorpusMeta: 0,
      quarantinedFolders: 0,
      quarantinedCorpora: 0,
      checkedFolders: 0,
      checkedCorpora: 0
    }
    let quarantineDir = null

    const ensureQuarantineDir = async () => {
      if (quarantineDir) return quarantineDir
      quarantineDir = await this.buildUniquePath(
        path.join(paths.repairRootDir, `repair-${this.createTimestampLabel()}`)
      )
      await this.ensureDirectory(quarantineDir)
      return quarantineDir
    }

    const quarantineFolderEntry = async entryPath => {
      const root = await ensureQuarantineDir()
      await this.moveEntryToQuarantine(entryPath, root, 'invalid-folders')
      summary.quarantinedFolders += 1
    }

    const quarantineCorpusEntry = async (entryPath, folderId, reason) => {
      const root = await ensureQuarantineDir()
      await this.moveEntryToQuarantine(entryPath, root, reason, folderId)
      summary.quarantinedCorpora += 1
    }

    const manifestBefore = await this.readJsonFile(paths.manifestPath, null)
    const manifestAfter = await this.ensureCorpusLibraryManifest()
    summary.repairedManifest =
      !manifestBefore || JSON.stringify(manifestBefore) !== JSON.stringify(manifestAfter)

    const folderEntries = await fs.readdir(paths.foldersDir, { withFileTypes: true })
    for (const entry of folderEntries) {
      const entryPath = path.join(paths.foldersDir, entry.name)
      if (!entry.isDirectory() || !this.isSafeStorageId(entry.name)) {
        await quarantineFolderEntry(entryPath)
        continue
      }

      summary.checkedFolders += 1
      const folderPaths = this.getFolderPaths(entry.name)
      const folderStats = await fs.stat(folderPaths.folderDir)
      const rawFolderMeta = await this.readJsonFile(folderPaths.folderMetaPath, null)
      const normalizedFolderMeta = this.normalizeFolderMeta(
        rawFolderMeta || { id: entry.name },
        entry.name,
        {
          createdAt: folderStats.birthtime.toISOString(),
          updatedAt: folderStats.mtime.toISOString()
        }
      )
      let folderTouched = false

      if (!rawFolderMeta || !this.isSameFolderMeta(rawFolderMeta, normalizedFolderMeta)) {
        await this.writeJsonFileAtomic(folderPaths.folderMetaPath, normalizedFolderMeta)
        folderTouched = true
      }

      if (!(await this.pathExists(folderPaths.corporaDir))) {
        await this.ensureDirectory(folderPaths.corporaDir)
        folderTouched = true
      }

      if (folderTouched) {
        summary.repairedFolders += 1
      }

      const corpusEntries = await fs.readdir(folderPaths.corporaDir, { withFileTypes: true })
      for (const corpusEntry of corpusEntries) {
        const corpusEntryPath = path.join(folderPaths.corporaDir, corpusEntry.name)
        if (!corpusEntry.isDirectory() || !this.isSafeStorageId(corpusEntry.name)) {
          await quarantineCorpusEntry(corpusEntryPath, normalizedFolderMeta.id, 'invalid-corpora')
          continue
        }

        summary.checkedCorpora += 1
        const recordPaths = this.getCorpusRecordPaths(normalizedFolderMeta.id, corpusEntry.name)
        if (!(await this.pathExists(recordPaths.contentPath))) {
          await quarantineCorpusEntry(recordPaths.corpusDir, normalizedFolderMeta.id, 'orphan-corpora')
          continue
        }

        const contentStats = await fs.stat(recordPaths.contentPath)
        const rawMeta = await this.readJsonFile(recordPaths.corpusMetaPath, null)
        const normalizedMeta = this.normalizeCorpusMeta(
          rawMeta || {
            id: corpusEntry.name,
            folderId: normalizedFolderMeta.id,
            name: this.sanitizeCorpusName(corpusEntry.name) || '未命名语料',
            originalName: `${corpusEntry.name}.txt`,
            sourceType: 'txt',
            createdAt: contentStats.birthtime.toISOString(),
            updatedAt: contentStats.mtime.toISOString()
          },
          corpusEntry.name,
          normalizedFolderMeta.id,
          {
            createdAt: contentStats.birthtime.toISOString(),
            updatedAt: contentStats.mtime.toISOString()
          }
        )
        const currentContent = await fs.readFile(recordPaths.contentPath, 'utf-8')
        const normalizedContent = this.normalizeCorpusText(currentContent)
        let corpusTouched = false

        if (!rawMeta || !this.isSameCorpusMeta(rawMeta, normalizedMeta)) {
          await this.writeJsonFileAtomic(recordPaths.corpusMetaPath, normalizedMeta)
          corpusTouched = true
          if (!rawMeta) {
            summary.recoveredCorpusMeta += 1
          }
        }

        if (currentContent !== normalizedContent) {
          await this.writeTextFileAtomic(recordPaths.contentPath, normalizedContent)
          corpusTouched = true
        }

        if (corpusTouched) {
          summary.repairedCorpora += 1
        }
      }
    }

    return {
      success: true,
      summary,
      quarantineDir
    }
  }

  async createFolder(name) {
    await this.prepare()
    const cleanName = this.sanitizeFolderName(name)

    if (!cleanName) {
      return {
        success: false,
        message: '文件夹名称不能为空'
      }
    }

    const existingFolders = await this.getRealFolderMetas()
    if (existingFolders.some(folder => folder.name === cleanName)) {
      return {
        success: false,
        message: '已经存在同名文件夹'
      }
    }

    const now = new Date().toISOString()
    const folderId = this.generateFolderId()
    const folder = await this.ensureFolderMeta(folderId, {
      id: folderId,
      name: cleanName,
      createdAt: now,
      updatedAt: now
    })

    return {
      success: true,
      folder: {
        ...folder,
        itemCount: 0,
        canRename: true,
        canDelete: true
      }
    }
  }

  async renameFolder(folderId, newName) {
    await this.prepare()
    const cleanName = this.sanitizeFolderName(newName)

    if (!cleanName) {
      return {
        success: false,
        message: '文件夹名称不能为空'
      }
    }

    const folder = await this.readSavedFolderMeta(folderId)

    if (!folder) {
      return {
        success: false,
        message: '找不到该文件夹'
      }
    }

    if (folder.system) {
      return {
        success: false,
        message: '默认文件夹不能重命名'
      }
    }

    const existingFolders = await this.getRealFolderMetas()
    if (existingFolders.some(item => item.id !== folderId && item.name === cleanName)) {
      return {
        success: false,
        message: '已经存在同名文件夹'
      }
    }

    const nextFolder = {
      ...folder,
      name: cleanName,
      updatedAt: new Date().toISOString()
    }
    const folderPaths = this.getFolderPaths(folderId)
    await this.writeJsonFileAtomic(folderPaths.folderMetaPath, nextFolder)

    return {
      success: true,
      folder: {
        ...nextFolder,
        canRename: true,
        canDelete: true
      }
    }
  }

  async moveCorpus(corpusId, targetFolderId) {
    await this.prepare()
    const normalizedCorpusId = this.assertStorageId(corpusId, '语料 ID')
    const record = await this.findSavedCorpusRecord(normalizedCorpusId)

    if (!record) {
      return {
        success: false,
        message: '找不到该语料'
      }
    }

    const targetFolder = await this.resolveFolderMeta(targetFolderId)
    if (record.folder.id === targetFolder.id) {
      return {
        success: true,
        item: this.decorateCorpusItem(record.meta, targetFolder)
      }
    }

    const targetRecordPaths = this.getCorpusRecordPaths(targetFolder.id, normalizedCorpusId)
    if (await this.pathExists(targetRecordPaths.corpusDir)) {
      return {
        success: false,
        message: '目标文件夹中已存在同 ID 语料'
      }
    }

    await this.ensureDirectory(targetRecordPaths.corporaDir)
    await fs.rename(record.recordPaths.corpusDir, targetRecordPaths.corpusDir)

    const nextMeta = {
      ...record.meta,
      folderId: targetFolder.id,
      updatedAt: new Date().toISOString()
    }
    await this.writeJsonFileAtomic(targetRecordPaths.corpusMetaPath, nextMeta)
    await this.touchFolderUpdatedAt(record.folder.id, nextMeta.updatedAt)
    await this.touchFolderUpdatedAt(targetFolder.id, nextMeta.updatedAt)

    return {
      success: true,
      item: this.decorateCorpusItem(nextMeta, targetFolder)
    }
  }

  async deleteFolder(folderId) {
    await this.prepare()
    const folder = await this.readSavedFolderMeta(folderId)

    if (!folder) {
      return {
        success: false,
        message: '找不到该文件夹'
      }
    }

    if (folder.system) {
      return {
        success: false,
        message: '默认文件夹不能删除'
      }
    }

    const folderPaths = this.getFolderPaths(folderId)
    const corpusEntries = (await this.pathExists(folderPaths.corporaDir))
      ? (await fs.readdir(folderPaths.corporaDir, { withFileTypes: true })).filter(
          entry => entry.isDirectory() && this.isSafeStorageId(entry.name)
        )
      : []
    const recycleEntryId = this.generateRecycleEntryId('folder')
    const recyclePaths = this.getRecycleEntryPaths('folder', recycleEntryId)
    const deletedAt = new Date().toISOString()

    await this.ensureDirectory(recyclePaths.entryDir)
    await fs.rename(folderPaths.folderDir, recyclePaths.recordDir)
    await this.writeJsonFileAtomic(recyclePaths.metaPath, {
      schemaVersion: CORPUS_LIBRARY_SCHEMA_VERSION,
      recycleEntryId,
      type: 'folder',
      deletedAt,
      itemCount: corpusEntries.length,
      folder
    })

    return {
      success: true,
      recycleEntryId,
      itemCount: corpusEntries.length
    }
  }

  async restoreDeletedCorpus(entry) {
    const deletedCorpus = this.buildRecycleCorpusEntry(entry.rawMeta)
    if (!(await this.pathExists(entry.entryPaths.recordDir))) {
      return {
        success: false,
        message: '回收站中的语料记录已损坏'
      }
    }

    const preferredFolder = await this.readSavedFolderMeta(deletedCorpus.originalFolderId)
    const targetFolder = preferredFolder || (await this.ensureDefaultFolder())
    const preferredCorpusId = this.isSafeStorageId(deletedCorpus.item?.id)
      ? this.normalizeStorageId(deletedCorpus.item.id)
      : this.generateCorpusId()
    const targetCorpusId = (await this.findSavedCorpusRecord(preferredCorpusId))
      ? this.generateCorpusId()
      : preferredCorpusId
    const targetRecordPaths = this.getCorpusRecordPaths(targetFolder.id, targetCorpusId)

    await this.ensureDirectory(targetRecordPaths.corporaDir)
    await fs.rename(entry.entryPaths.recordDir, targetRecordPaths.corpusDir)

    const rawMeta = await this.readJsonFile(targetRecordPaths.corpusMetaPath, deletedCorpus.item)
    const restoredAt = new Date().toISOString()
    const restoredMeta = this.normalizeCorpusMeta(
      {
        ...deletedCorpus.item,
        ...rawMeta,
        id: targetCorpusId,
        folderId: targetFolder.id,
        updatedAt: restoredAt
      },
      targetCorpusId,
      targetFolder.id,
      {
        createdAt: deletedCorpus.item?.createdAt || restoredAt,
        updatedAt: restoredAt
      }
    )

    await this.writeJsonFileAtomic(targetRecordPaths.corpusMetaPath, restoredMeta)
    await this.touchFolderUpdatedAt(targetFolder.id, restoredMeta.updatedAt)
    await fs.rm(entry.entryPaths.entryDir, { recursive: true, force: true })

    return {
      success: true,
      restoredType: 'corpus',
      item: this.decorateCorpusItem(restoredMeta, targetFolder),
      restoredToOriginalFolder: targetFolder.id === deletedCorpus.originalFolderId
    }
  }

  async restoreDeletedFolder(entry) {
    const deletedFolder = this.buildRecycleFolderEntry(entry.rawMeta)
    if (!(await this.pathExists(entry.entryPaths.recordDir))) {
      return {
        success: false,
        message: '回收站中的文件夹记录已损坏'
      }
    }

    const preferredFolderId = this.isSafeStorageId(deletedFolder.folder?.id)
      ? this.normalizeStorageId(deletedFolder.folder.id)
      : this.generateFolderId()
    const targetFolderId = (await this.readSavedFolderMeta(preferredFolderId))
      ? this.generateFolderId()
      : preferredFolderId
    const targetFolderPaths = this.getFolderPaths(targetFolderId)
    const restoredAt = new Date().toISOString()

    await fs.rename(entry.entryPaths.recordDir, targetFolderPaths.folderDir)
    await this.ensureDirectory(targetFolderPaths.corporaDir)

    const folderMeta = this.normalizeFolderMeta(
      {
        ...deletedFolder.folder,
        id: targetFolderId,
        system: false,
        updatedAt: restoredAt
      },
      targetFolderId,
      {
        createdAt: deletedFolder.folder?.createdAt || restoredAt,
        updatedAt: restoredAt
      }
    )
    await this.writeJsonFileAtomic(targetFolderPaths.folderMetaPath, folderMeta)

    if (targetFolderId !== preferredFolderId) {
      const corpusEntries = await fs.readdir(targetFolderPaths.corporaDir, { withFileTypes: true })
      for (const corpusEntry of corpusEntries) {
        if (!corpusEntry.isDirectory() || !this.isSafeStorageId(corpusEntry.name)) {
          continue
        }

        const recordPaths = this.getCorpusRecordPaths(targetFolderId, corpusEntry.name)
        const rawMeta = await this.readJsonFile(recordPaths.corpusMetaPath, null)
        const nextMeta = this.normalizeCorpusMeta(
          {
            ...rawMeta,
            id: corpusEntry.name,
            folderId: targetFolderId,
            updatedAt: restoredAt
          },
          corpusEntry.name,
          targetFolderId,
          {
            createdAt: rawMeta?.createdAt || restoredAt,
            updatedAt: restoredAt
          }
        )
        await this.writeJsonFileAtomic(recordPaths.corpusMetaPath, nextMeta)
      }
    }

    await fs.rm(entry.entryPaths.entryDir, { recursive: true, force: true })

    return {
      success: true,
      restoredType: 'folder',
      folder: {
        ...folderMeta,
        itemCount: deletedFolder.itemCount
      },
      restoredAsNewFolder: targetFolderId !== preferredFolderId
    }
  }

  async restoreRecycleEntry(recycleEntryId) {
    await this.prepare()
    const entry = await this.findRecycleEntry(recycleEntryId)

    if (!entry) {
      return {
        success: false,
        message: '找不到该回收站项目'
      }
    }

    if (entry.type === 'folder') {
      return this.restoreDeletedFolder(entry)
    }

    return this.restoreDeletedCorpus(entry)
  }

  async purgeRecycleEntry(recycleEntryId) {
    await this.prepare()
    const entry = await this.findRecycleEntry(recycleEntryId)

    if (!entry) {
      return {
        success: false,
        message: '找不到该回收站项目'
      }
    }

    await fs.rm(entry.entryPaths.entryDir, { recursive: true, force: true })
    return {
      success: true,
      purgedType: entry.type
    }
  }

  async importCorpus({ originalName, sourceType, content, folderId }) {
    await this.prepare()
    const targetFolder = await this.resolveFolderMeta(folderId)
    const corpusId = this.generateCorpusId()
    const now = new Date().toISOString()
    const displayName =
      this.sanitizeCorpusName(path.basename(originalName, path.extname(originalName))) || '未命名语料'
    const savedRecord = await this.writeSavedCorpusRecord({
      folderId: targetFolder.id,
      corpusId,
      rawMeta: {
        id: corpusId,
        folderId: targetFolder.id,
        name: displayName,
        originalName,
        sourceType,
        createdAt: now,
        updatedAt: now
      },
      content
    })

    return {
      meta: this.decorateCorpusItem(savedRecord.meta, savedRecord.folder),
      filePath: savedRecord.recordPaths.contentPath,
      fileName: path.basename(savedRecord.recordPaths.contentPath)
    }
  }

  async listLibrary(folderId = 'all') {
    await this.prepare()
    return {
      success: true,
      ...(await this.buildCorpusLibrarySnapshot(folderId))
    }
  }

  async listSearchableCorpora(folderId = 'all') {
    await this.prepare()
    const snapshot = await this.buildCorpusLibrarySnapshot(folderId)
    const selectedFolder =
      snapshot.selectedFolderId === 'all'
        ? null
        : snapshot.folders.find(folder => folder.id === snapshot.selectedFolderId) || null
    const corpora = []

    for (const item of snapshot.items) {
      const recordPaths = this.getCorpusRecordPaths(item.folderId, item.id)
      if (!(await this.pathExists(recordPaths.contentPath))) {
        continue
      }

      const content = this.normalizeCorpusText(await fs.readFile(recordPaths.contentPath, 'utf-8'))
      if (!content) {
        continue
      }

      corpora.push({
        corpusId: item.id,
        corpusName: item.name,
        folderId: item.folderId,
        folderName: item.folderName,
        sourceType: this.normalizeSourceType(item.sourceType),
        content,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      })
    }

    return {
      success: true,
      selectedFolderId: snapshot.selectedFolderId,
      selectedFolderName: selectedFolder ? selectedFolder.name : '全部本地语料',
      totalCount: corpora.length,
      corpora
    }
  }

  async openCorpus(corpusId) {
    await this.prepare()
    const normalizedCorpusId = this.assertStorageId(corpusId, '语料 ID')
    const record = await this.findSavedCorpusRecord(normalizedCorpusId)

    if (!record) {
      return {
        success: false,
        message: '找不到该语料'
      }
    }

    if (!(await this.pathExists(record.recordPaths.contentPath))) {
      return {
        success: false,
        message: '语料文件不存在'
      }
    }

    const content = this.normalizeCorpusText(await fs.readFile(record.recordPaths.contentPath, 'utf-8'))

    return {
      success: true,
      mode: 'saved',
      corpusId: record.meta.id,
      filePath: record.recordPaths.contentPath,
      fileName: path.basename(record.recordPaths.contentPath),
      displayName: record.meta.name,
      folderId: record.folder.id,
      folderName: record.folder.name,
      content
    }
  }

  async openCorpora(corpusIds = []) {
    await this.prepare()
    const normalizedCorpusIds = Array.isArray(corpusIds)
      ? [...new Set(corpusIds.map(corpusId => this.assertStorageId(corpusId, '语料 ID')))]
      : []

    if (normalizedCorpusIds.length === 0) {
      return {
        success: false,
        message: '请至少选择一条语料'
      }
    }

    const items = []
    const contents = []

    for (const corpusId of normalizedCorpusIds) {
      const record = await this.findSavedCorpusRecord(corpusId)
      if (!record || !(await this.pathExists(record.recordPaths.contentPath))) {
        continue
      }

      const content = this.normalizeCorpusText(await fs.readFile(record.recordPaths.contentPath, 'utf-8'))
      if (!content) continue

      items.push({
        id: record.meta.id,
        name: record.meta.name,
        folderId: record.folder.id,
        folderName: record.folder.name,
        sourceType: this.normalizeSourceType(record.meta.sourceType),
        filePath: record.recordPaths.contentPath
      })
      contents.push(content)
    }

    if (items.length === 0) {
      return {
        success: false,
        message: '所选语料不存在或内容为空'
      }
    }

    const uniqueFolderNames = [...new Set(items.map(item => item.folderName || DEFAULT_FOLDER_NAME))]
    const folderLabel = uniqueFolderNames.length === 1 ? uniqueFolderNames[0] : '多个分类'

    return {
      success: true,
      mode: items.length === 1 ? 'saved' : 'saved-multi',
      corpusId: items.length === 1 ? items[0].id : '',
      corpusIds: items.map(item => item.id),
      displayName: items.length === 1 ? items[0].name : `已选 ${items.length} 条语料`,
      folderId: items.length === 1 ? items[0].folderId : '',
      folderName: folderLabel,
      content: contents.join('\n\n'),
      selectedItems: items,
      comparisonEntries: items.map((item, index) => ({
        corpusId: item.id,
        corpusName: item.name,
        folderId: item.folderId,
        folderName: item.folderName,
        sourceType: item.sourceType,
        content: contents[index] || ''
      }))
    }
  }

  async renameCorpus(corpusId, newName) {
    await this.prepare()
    const normalizedCorpusId = this.assertStorageId(corpusId, '语料 ID')
    const cleanName = this.sanitizeCorpusName(newName)

    if (!cleanName) {
      return {
        success: false,
        message: '名称不能为空'
      }
    }

    const record = await this.findSavedCorpusRecord(normalizedCorpusId)

    if (!record) {
      return {
        success: false,
        message: '找不到该语料'
      }
    }

    const nextItem = {
      ...record.meta,
      name: cleanName,
      updatedAt: new Date().toISOString()
    }
    await this.writeJsonFileAtomic(record.recordPaths.corpusMetaPath, nextItem)
    await this.touchFolderUpdatedAt(record.folder.id, nextItem.updatedAt)

    return {
      success: true,
      item: this.decorateCorpusItem(nextItem, record.folder)
    }
  }

  async deleteCorpus(corpusId) {
    await this.prepare()
    const normalizedCorpusId = this.assertStorageId(corpusId, '语料 ID')
    const record = await this.findSavedCorpusRecord(normalizedCorpusId)

    if (!record) {
      return {
        success: false,
        message: '找不到该语料'
      }
    }

    const recycleEntryId = this.generateRecycleEntryId('corpus')
    const recyclePaths = this.getRecycleEntryPaths('corpus', recycleEntryId)
    const deletedAt = new Date().toISOString()

    await this.ensureDirectory(recyclePaths.entryDir)
    await fs.rename(record.recordPaths.corpusDir, recyclePaths.recordDir)
    await this.writeJsonFileAtomic(recyclePaths.metaPath, {
      schemaVersion: CORPUS_LIBRARY_SCHEMA_VERSION,
      recycleEntryId,
      type: 'corpus',
      deletedAt,
      originalFolderId: record.folder.id,
      originalFolderName: record.folder.name,
      item: record.item
    })
    await this.touchFolderUpdatedAt(record.folder.id, deletedAt)

    return {
      success: true,
      recycleEntryId,
      item: record.item
    }
  }
}

module.exports = {
  CorpusStorage,
  CORPUS_LIBRARY_SCHEMA_VERSION,
  DEFAULT_FOLDER_ID,
  DEFAULT_FOLDER_NAME
}
