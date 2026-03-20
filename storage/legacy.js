function installCorpusStorageLegacy(CorpusStorage, { path, fs, DEFAULT_FOLDER_ID }) {
  Object.assign(CorpusStorage.prototype, {
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
    },

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
    },

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
    },

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
    },

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
    },

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
  })
}

module.exports = {
  installCorpusStorageLegacy
}
