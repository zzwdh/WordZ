function installCorpusStorageRecycle(CorpusStorage, { path, fs, CORPUS_LIBRARY_SCHEMA_VERSION, DEFAULT_FOLDER_ID, DEFAULT_FOLDER_NAME }) {
  Object.assign(CorpusStorage.prototype, {
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
    },

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
    },

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
    },

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
    },

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
    },

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
    },

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
    },

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
    },

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
    },

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
    },

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
    },

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
    },

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
  })
}

module.exports = {
  installCorpusStorageRecycle
}
