const path = require('path')
const fs = require('fs/promises')
const { installCorpusStorageShared } = require('./storage/shared')
const { installCorpusStorageLegacy } = require('./storage/legacy')
const { installCorpusStorageRecycle } = require('./storage/recycle')

const CORPUS_LIBRARY_SCHEMA_VERSION = 3
const DEFAULT_FOLDER_ID = 'uncategorized'
const DEFAULT_FOLDER_NAME = '未分类'
const SAFE_STORAGE_ID_PATTERN = /^[A-Za-z0-9_-]{1,160}$/

class CorpusStorage {
  constructor(baseDir) {
    this.baseDir = baseDir
    this.preparePromise = null
    this.storageWriteQueue = Promise.resolve()
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

installCorpusStorageShared(CorpusStorage, {
  path,
  fs,
  CORPUS_LIBRARY_SCHEMA_VERSION,
  DEFAULT_FOLDER_ID,
  DEFAULT_FOLDER_NAME,
  SAFE_STORAGE_ID_PATTERN
})

installCorpusStorageLegacy(CorpusStorage, {
  path,
  fs,
  DEFAULT_FOLDER_ID
})

installCorpusStorageRecycle(CorpusStorage, {
  path,
  fs,
  CORPUS_LIBRARY_SCHEMA_VERSION,
  DEFAULT_FOLDER_ID,
  DEFAULT_FOLDER_NAME
})

module.exports = {
  CorpusStorage,
  CORPUS_LIBRARY_SCHEMA_VERSION,
  DEFAULT_FOLDER_ID,
  DEFAULT_FOLDER_NAME
}
