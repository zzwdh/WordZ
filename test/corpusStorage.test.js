const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('fs/promises')
const os = require('os')
const path = require('path')

const { CorpusStorage, DEFAULT_FOLDER_ID } = require('../corpusStorage')

async function createTempLibrary(t) {
  const baseDir = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-storage-'))
  t.after(async () => {
    await fs.rm(baseDir, { recursive: true, force: true })
  })
  return baseDir
}

test('migrates legacy flat storage into the default folder', async t => {
  const baseDir = await createTempLibrary(t)
  const legacyItem = {
    id: 'legacy-flat-1',
    name: '旧语料',
    fileName: 'legacy-flat-1.txt',
    originalName: 'legacy.txt',
    sourceType: 'txt',
    createdAt: '2024-01-01T00:00:00.000Z',
    updatedAt: '2024-01-02T00:00:00.000Z'
  }

  await fs.writeFile(path.join(baseDir, 'index.json'), JSON.stringify([legacyItem], null, 2), 'utf-8')
  await fs.mkdir(path.join(baseDir, 'items'), { recursive: true })
  await fs.writeFile(path.join(baseDir, 'items', 'legacy-flat-1.txt'), 'alpha beta gamma', 'utf-8')

  const storage = new CorpusStorage(baseDir)
  const snapshot = await storage.listLibrary('all')

  assert.equal(snapshot.success, true)
  assert.equal(snapshot.totalCount, 1)
  assert.equal(snapshot.items[0].id, 'legacy-flat-1')
  assert.equal(snapshot.items[0].folderId, DEFAULT_FOLDER_ID)
  assert.equal(snapshot.items[0].folderName, '未分类')

  const archivedIndex = path.join(baseDir, 'legacy-v1', 'index.json')
  const archivedItemsDir = path.join(baseDir, 'legacy-v1', 'items')
  const migratedContent = path.join(baseDir, 'folders', DEFAULT_FOLDER_ID, 'corpora', 'legacy-flat-1', 'content.txt')

  assert.equal(await fs.readFile(migratedContent, 'utf-8'), 'alpha beta gamma')
  assert.equal(await fs.readFile(archivedIndex, 'utf-8').then(Boolean), true)
  assert.equal((await fs.readdir(archivedItemsDir)).includes('legacy-flat-1.txt'), true)
})

test('supports recycle-bin restore for deleted corpora and folders', async t => {
  const baseDir = await createTempLibrary(t)
  const storage = new CorpusStorage(baseDir)

  const folderA = await storage.createFolder('文学')
  const folderB = await storage.createFolder('论文')
  assert.equal(folderA.success, true)
  assert.equal(folderB.success, true)

  const imported = await storage.importCorpus({
    originalName: 'poem.txt',
    sourceType: 'txt',
    content: 'rose rose red',
    folderId: folderA.folder.id
  })

  assert.equal(imported.meta.folderId, folderA.folder.id)

  const moved = await storage.moveCorpus(imported.meta.id, folderB.folder.id)
  assert.equal(moved.success, true)
  assert.equal(moved.item.folderId, folderB.folder.id)

  const deletedCorpus = await storage.deleteCorpus(imported.meta.id)
  assert.equal(deletedCorpus.success, true)
  assert.ok(deletedCorpus.recycleEntryId)

  let snapshot = await storage.listLibrary('all')
  assert.equal(snapshot.items.some(item => item.id === imported.meta.id), false)

  let recycleBin = await storage.listRecycleBin()
  assert.equal(recycleBin.totalCount, 1)
  assert.equal(recycleBin.entries[0].type, 'corpus')

  const restoredCorpus = await storage.restoreRecycleEntry(deletedCorpus.recycleEntryId)
  assert.equal(restoredCorpus.success, true)
  assert.equal(restoredCorpus.restoredType, 'corpus')
  assert.equal(restoredCorpus.item.folderId, folderB.folder.id)

  snapshot = await storage.listLibrary('all')
  const restoredItem = snapshot.items.find(item => item.id === restoredCorpus.item.id)
  assert.ok(restoredItem)
  assert.equal(restoredItem.folderId, folderB.folder.id)

  const deletedFolder = await storage.deleteFolder(folderB.folder.id)
  assert.equal(deletedFolder.success, true)
  assert.ok(deletedFolder.recycleEntryId)
  assert.equal(deletedFolder.itemCount, 1)

  snapshot = await storage.listLibrary('all')
  assert.equal(snapshot.items.some(item => item.folderId === folderB.folder.id), false)
  assert.equal(snapshot.folders.some(folder => folder.id === folderB.folder.id), false)

  recycleBin = await storage.listRecycleBin()
  assert.equal(recycleBin.totalCount, 1)
  assert.equal(recycleBin.entries[0].type, 'folder')

  const restoredFolder = await storage.restoreRecycleEntry(deletedFolder.recycleEntryId)
  assert.equal(restoredFolder.success, true)
  assert.equal(restoredFolder.restoredType, 'folder')

  snapshot = await storage.listLibrary('all')
  const returnedFolder = snapshot.folders.find(folder => folder.id === restoredFolder.folder.id)
  assert.ok(returnedFolder)
  assert.equal(snapshot.items.some(item => item.folderId === restoredFolder.folder.id), true)
})

test('supports purging recycle-bin entries permanently', async t => {
  const baseDir = await createTempLibrary(t)
  const storage = new CorpusStorage(baseDir)

  const imported = await storage.importCorpus({
    originalName: 'purge.txt',
    sourceType: 'txt',
    content: 'alpha beta gamma',
    folderId: DEFAULT_FOLDER_ID
  })

  const deletedCorpus = await storage.deleteCorpus(imported.meta.id)
  assert.equal(deletedCorpus.success, true)

  let recycleBin = await storage.listRecycleBin()
  assert.equal(recycleBin.totalCount, 1)

  const purged = await storage.purgeRecycleEntry(deletedCorpus.recycleEntryId)
  assert.equal(purged.success, true)
  assert.equal(purged.purgedType, 'corpus')

  recycleBin = await storage.listRecycleBin()
  assert.equal(recycleBin.totalCount, 0)
  const snapshot = await storage.listLibrary('all')
  assert.equal(snapshot.items.some(item => item.id === imported.meta.id), false)
})

test('lists searchable corpora for current folder and full library scopes', async t => {
  const baseDir = await createTempLibrary(t)
  const storage = new CorpusStorage(baseDir)
  const folder = await storage.createFolder('检索测试')
  await storage.importCorpus({
    originalName: 'folder-search.txt',
    sourceType: 'txt',
    content: 'rose bloom bright',
    folderId: folder.folder.id
  })
  await storage.importCorpus({
    originalName: 'all-search.txt',
    sourceType: 'txt',
    content: 'white rose fades',
    folderId: DEFAULT_FOLDER_ID
  })

  const folderScope = await storage.listSearchableCorpora(folder.folder.id)
  assert.equal(folderScope.success, true)
  assert.equal(folderScope.selectedFolderId, folder.folder.id)
  assert.equal(folderScope.selectedFolderName, folder.folder.name)
  assert.equal(folderScope.totalCount, 1)
  assert.equal(folderScope.corpora[0].corpusName, 'folder-search')
  assert.equal(folderScope.corpora[0].content, undefined)
  assert.equal(folderScope.corpora[0].contentLength, undefined)

  const allScope = await storage.listSearchableCorpora('all')
  assert.equal(allScope.success, true)
  assert.equal(allScope.selectedFolderId, 'all')
  assert.equal(allScope.totalCount, 2)
  assert.equal(allScope.corpora.some(item => item.folderId === folder.folder.id), true)
  assert.equal(allScope.corpora.some(item => item.folderId === DEFAULT_FOLDER_ID), true)
})

test('migrates legacy folderless corpora layout into foldered storage', async t => {
  const baseDir = await createTempLibrary(t)
  const legacyCorpusDir = path.join(baseDir, 'corpora', 'legacy-v2-1')
  await fs.mkdir(legacyCorpusDir, { recursive: true })
  await fs.writeFile(
    path.join(legacyCorpusDir, 'meta.json'),
    JSON.stringify(
      {
        id: 'legacy-v2-1',
        name: '第二代语料',
        originalName: 'legacy-v2.txt',
        sourceType: 'txt',
        createdAt: '2024-02-01T00:00:00.000Z',
        updatedAt: '2024-02-02T00:00:00.000Z'
      },
      null,
      2
    ),
    'utf-8'
  )
  await fs.writeFile(path.join(legacyCorpusDir, 'content.txt'), 'delta epsilon', 'utf-8')

  const storage = new CorpusStorage(baseDir)
  const opened = await storage.openCorpus('legacy-v2-1')

  assert.equal(opened.success, true)
  assert.equal(opened.folderId, DEFAULT_FOLDER_ID)
  assert.equal(opened.content, 'delta epsilon')

  const archivedDir = path.join(baseDir, 'legacy-v2', 'corpora', 'legacy-v2-1')
  const migratedDir = path.join(baseDir, 'folders', DEFAULT_FOLDER_ID, 'corpora', 'legacy-v2-1')
  assert.equal(await fs.readFile(path.join(migratedDir, 'content.txt'), 'utf-8'), 'delta epsilon')
  assert.equal((await fs.readdir(path.dirname(archivedDir))).includes('legacy-v2-1'), true)
})

test('rejects unsafe folder and corpus identifiers', async t => {
  const baseDir = await createTempLibrary(t)
  const storage = new CorpusStorage(baseDir)
  const folder = await storage.createFolder('安全语料')
  const imported = await storage.importCorpus({
    originalName: 'safe.txt',
    sourceType: 'txt',
    content: 'alpha beta',
    folderId: folder.folder.id
  })

  await assert.rejects(
    () => storage.listLibrary('../outside'),
    /文件夹 ID格式不合法/
  )

  await assert.rejects(
    () => storage.moveCorpus(imported.meta.id, '../outside'),
    /文件夹 ID格式不合法/
  )

  await assert.rejects(
    () => storage.openCorpus('../outside'),
    /语料 ID格式不合法/
  )
})

test('creates a full library backup outside the storage directory', async t => {
  const baseDir = await createTempLibrary(t)
  const backupRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-backup-'))
  t.after(async () => {
    await fs.rm(backupRoot, { recursive: true, force: true })
  })

  const storage = new CorpusStorage(baseDir)
  const folder = await storage.createFolder('备份测试')
  await storage.importCorpus({
    originalName: 'backup.txt',
    sourceType: 'txt',
    content: 'alpha beta gamma',
    folderId: folder.folder.id
  })

  const result = await storage.backupLibrary(backupRoot)
  assert.equal(result.success, true)
  assert.equal(result.folderCount, 2)
  assert.equal(result.corpusCount, 1)
  assert.equal(await fs.readFile(path.join(result.backupDir, 'library.json'), 'utf-8').then(Boolean), true)
  assert.equal(
    await fs.access(path.join(result.backupDir, 'folders', folder.folder.id, 'corpora')).then(() => true).catch(() => false),
    true
  )

  const copiedContentPath = path.join(
    result.backupDir,
    'folders',
    folder.folder.id,
    'corpora',
    (await storage.listLibrary('all')).items[0].id,
    'content.txt'
  )
  assert.equal(await fs.readFile(copiedContentPath, 'utf-8'), 'alpha beta gamma')
})

test('restores library from backup and keeps a snapshot of the previous state', async t => {
  const baseDir = await createTempLibrary(t)
  const backupRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-restore-'))
  t.after(async () => {
    await fs.rm(backupRoot, { recursive: true, force: true })
  })

  const storage = new CorpusStorage(baseDir)
  const originalFolder = await storage.createFolder('恢复测试')
  const originalCorpus = await storage.importCorpus({
    originalName: 'restore-source.txt',
    sourceType: 'txt',
    content: 'alpha beta gamma',
    folderId: originalFolder.folder.id
  })

  const backupResult = await storage.backupLibrary(backupRoot)
  assert.equal(backupResult.success, true)

  const extraFolder = await storage.createFolder('恢复后新增')
  const extraCorpus = await storage.importCorpus({
    originalName: 'after-backup.txt',
    sourceType: 'txt',
    content: 'delta epsilon zeta',
    folderId: extraFolder.folder.id
  })
  await storage.deleteCorpus(originalCorpus.meta.id)

  const restoreResult = await storage.restoreLibrary(backupResult.backupDir)
  assert.equal(restoreResult.success, true)
  assert.equal(restoreResult.folderCount, 2)
  assert.equal(restoreResult.corpusCount, 1)
  assert.ok(restoreResult.previousLibraryBackupDir)

  t.after(async () => {
    if (restoreResult.previousLibraryBackupDir) {
      await fs.rm(restoreResult.previousLibraryBackupDir, { recursive: true, force: true })
    }
  })

  const restoredSnapshot = await storage.listLibrary('all')
  assert.equal(restoredSnapshot.totalCount, 1)
  assert.equal(restoredSnapshot.items[0].id, originalCorpus.meta.id)
  assert.equal(restoredSnapshot.items[0].folderId, originalFolder.folder.id)
  assert.equal(restoredSnapshot.items.some(item => item.id === extraCorpus.meta.id), false)

  const previousStateContent = path.join(
    restoreResult.previousLibraryBackupDir,
    'folders',
    extraFolder.folder.id,
    'corpora',
    extraCorpus.meta.id,
    'content.txt'
  )
  assert.equal(await fs.readFile(previousStateContent, 'utf-8'), 'delta epsilon zeta')
})

test('repairs missing metadata and quarantines malformed entries', async t => {
  const baseDir = await createTempLibrary(t)
  const storage = new CorpusStorage(baseDir)
  const folder = await storage.createFolder('修复测试')
  const imported = await storage.importCorpus({
    originalName: 'repair.txt',
    sourceType: 'txt',
    content: 'rose bloom bright',
    folderId: folder.folder.id
  })

  const corpusDir = path.join(baseDir, 'folders', folder.folder.id, 'corpora', imported.meta.id)
  await fs.rm(path.join(corpusDir, 'meta.json'), { force: true })
  await fs.mkdir(path.join(baseDir, 'folders', 'bad folder'), { recursive: true })
  await fs.writeFile(path.join(baseDir, 'folders', 'bad folder', 'note.txt'), 'bad', 'utf-8')
  await fs.mkdir(path.join(baseDir, 'folders', folder.folder.id, 'corpora', 'bad corpus'), { recursive: true })
  await fs.writeFile(
    path.join(baseDir, 'folders', folder.folder.id, 'corpora', 'bad corpus', 'content.txt'),
    'broken',
    'utf-8'
  )

  const result = await storage.repairLibrary()
  assert.equal(result.success, true)
  assert.equal(result.summary.recoveredCorpusMeta, 1)
  assert.equal(result.summary.repairedCorpora >= 1, true)
  assert.equal(result.summary.quarantinedFolders, 1)
  assert.equal(result.summary.quarantinedCorpora, 1)
  assert.ok(result.quarantineDir)

  const reopened = await storage.openCorpus(imported.meta.id)
  assert.equal(reopened.success, true)
  assert.equal(reopened.displayName, imported.meta.id)
  assert.equal(await fs.readFile(path.join(corpusDir, 'meta.json'), 'utf-8').then(Boolean), true)
  assert.equal(await fs.access(path.join(baseDir, 'folders', 'bad folder')).then(() => true).catch(() => false), false)
  assert.equal(
    await fs.access(path.join(baseDir, 'folders', folder.folder.id, 'corpora', 'bad corpus')).then(() => true).catch(() => false),
    false
  )
})
