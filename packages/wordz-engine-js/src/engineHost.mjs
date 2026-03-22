import fs from 'node:fs/promises'
import path from 'node:path'
import { EventEmitter } from 'node:events'

import {
  ENGINE_ERROR_CODES,
  ENGINE_EVENTS,
  ENGINE_METHODS,
  JSON_RPC_VERSION
} from '../../wordz-contracts/src/index.mjs'
import { createAnalysisTaskRunner } from './analysisTaskRunner.mjs'
import { createWorkspaceStore } from './workspaceStore.mjs'
import {
  CorpusStorage,
  SUPPORTED_CORPUS_EXTENSIONS,
  createDiagnosticsController,
  inspectCorpusFilePreflight,
  normalizeIdentifier,
  normalizeTextInput,
  packageManifest,
  pathToFileURL,
  readCorpusFile,
  resolveUserDataDir
} from './rootModules.mjs'

const SUPPORTED_IMPORT_EXTENSIONS = new Set(
  Array.isArray(SUPPORTED_CORPUS_EXTENSIONS)
    ? SUPPORTED_CORPUS_EXTENSIONS
    : SUPPORTED_CORPUS_EXTENSIONS && typeof SUPPORTED_CORPUS_EXTENSIONS[Symbol.iterator] === 'function'
      ? [...SUPPORTED_CORPUS_EXTENSIONS]
      : ['.txt', '.docx', '.pdf']
)

function getSourceTypeFromExtension(extension) {
  if (extension === '.docx') return 'docx'
  if (extension === '.pdf') return 'pdf'
  return 'txt'
}

function normalizeLaunchFilePaths(filePaths = []) {
  return Array.isArray(filePaths)
    ? filePaths.map(item => String(item || '').trim()).filter(Boolean)
    : []
}

function createAppShim({ userDataDir, productName, version }) {
  return {
    getName() {
      return productName
    },
    getVersion() {
      return version
    },
    getPath(target) {
      if (target === 'userData') return userDataDir
      return userDataDir
    }
  }
}

async function pathExists(targetPath) {
  try {
    await fs.access(targetPath)
    return true
  } catch {
    return false
  }
}

async function runPreflightCheck(targetPath) {
  try {
    const result = await inspectCorpusFilePreflight(targetPath)
    const warnings = Array.isArray(result?.warnings) ? result.warnings.map(item => String(item || '').trim()).filter(Boolean) : []
    const errors = Array.isArray(result?.errors) ? result.errors.map(item => String(item || '').trim()).filter(Boolean) : []
    return {
      ok: result?.ok !== false && errors.length === 0,
      warnings,
      errors
    }
  } catch (error) {
    return {
      ok: false,
      warnings: [],
      errors: [error instanceof Error ? error.message : '导入前体检失败']
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
      if (cleanedSegment && cleanedSegment !== '.') {
        segments.push(cleanedSegment)
      }
    }
  }
  return segments.join(' ⟫ ')
}

async function collectImportEntriesFromPaths(rawInputPaths = []) {
  const collectedEntries = []
  const skippedEntries = []
  const visitedPaths = new Set()

  const collectSingleFile = (absolutePath, rootLabel = '', relativeDir = '') => {
    const extension = path.extname(absolutePath).toLowerCase()
    if (!SUPPORTED_IMPORT_EXTENSIONS.has(extension)) {
      skippedEntries.push({
        sourcePath: absolutePath,
        reason: '不支持的文件类型'
      })
      return
    }
    collectedEntries.push({
      sourcePath: absolutePath,
      extension,
      rootLabel,
      relativeDir
    })
  }

  const walkDirectory = async (rootDir, currentDir, rootLabel) => {
    const entries = await fs.readdir(currentDir, { withFileTypes: true })
    for (const entry of entries) {
      const absolutePath = path.join(currentDir, entry.name)
      if (entry.isDirectory()) {
        await walkDirectory(rootDir, absolutePath, rootLabel)
        continue
      }
      if (!entry.isFile()) continue
      const relativeDir = path.relative(rootDir, path.dirname(absolutePath))
      collectSingleFile(absolutePath, rootLabel, relativeDir === '.' ? '' : relativeDir)
    }
  }

  for (const rawInputPath of Array.isArray(rawInputPaths) ? rawInputPaths : []) {
    const normalizedPath = path.resolve(String(rawInputPath || '').trim())
    if (!normalizedPath || visitedPaths.has(normalizedPath)) {
      continue
    }
    visitedPaths.add(normalizedPath)
    try {
      const stats = await fs.stat(normalizedPath)
      if (stats.isDirectory()) {
        await walkDirectory(normalizedPath, normalizedPath, path.basename(normalizedPath))
      } else if (stats.isFile()) {
        collectSingleFile(normalizedPath, '', '')
      }
    } catch (error) {
      skippedEntries.push({
        sourcePath: normalizedPath,
        reason: error instanceof Error ? error.message : '路径不可读取'
      })
    }
  }

  return {
    collectedEntries,
    skippedEntries
  }
}

function buildAppInfo({ userDataDir, pendingLaunchFilePaths }) {
  return {
    success: true,
    appInfo: {
      name: packageManifest.productName || packageManifest.name || 'WordZ',
      version: String(packageManifest.version || ''),
      author: String(packageManifest.author || ''),
      description: String(packageManifest.description || ''),
      repositoryUrl: String(packageManifest.homepage || ''),
      help: Array.isArray(packageManifest?.wordz?.help) ? packageManifest.wordz.help : [],
      releaseNotes: Array.isArray(packageManifest?.wordz?.releaseNotes) ? packageManifest.wordz.releaseNotes : [],
      userDataDir,
      pendingLaunchFilePaths
    }
  }
}

export function createEngineHost(options = {}) {
  const userDataDir = resolveUserDataDir(options.userDataDir)
  const corpusLibraryDir = path.join(userDataDir, 'corpus-library')
  const productName = packageManifest.productName || packageManifest.name || 'WordZ'
  const appVersion = String(packageManifest.version || '')
  const pendingLaunchFilePaths = normalizeLaunchFilePaths(options.pendingLaunchFilePaths || [])
  const diagnosticsController = createDiagnosticsController({
    app: createAppShim({ userDataDir, productName, version: appVersion }),
    packageManifest,
    logger: console
  })
  const corpusStorage = new CorpusStorage(corpusLibraryDir)
  const workspaceStore = createWorkspaceStore({ userDataDir })
  const analysisTaskRunner = createAnalysisTaskRunner()
  const emitter = new EventEmitter()

  const unsubscribeTasks = analysisTaskRunner.onNotification(payload => {
    emitter.emit('notification', payload)
  })

  async function ensureStorageReady() {
    await corpusStorage.prepare()
    return corpusStorage
  }

  async function libraryOpenQuickPath({ filePath } = {}) {
    const resolvedFilePath = path.resolve(String(filePath || '').trim())
    if (!(await pathExists(resolvedFilePath))) {
      throw new Error('原始语料文件已不存在')
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
    const ext = path.extname(resolvedFilePath).toLowerCase()
    return {
      success: true,
      mode: 'quick',
      filePath: resolvedFilePath,
      fileName: path.basename(resolvedFilePath),
      displayName: path.basename(resolvedFilePath, ext),
      content,
      sourceType: getSourceTypeFromExtension(ext),
      sourceEncoding: encoding,
      preflightWarnings: preflight.warnings,
      preflightWarningCount: preflight.warnings.length
    }
  }

  async function libraryImportPaths({ paths: targetPaths = [], folderId = '', preserveHierarchy = true } = {}) {
    const storage = await ensureStorageReady()
    const { collectedEntries, skippedEntries } = await collectImportEntriesFromPaths(targetPaths)
    if (collectedEntries.length === 0) {
      return {
        success: false,
        message: skippedEntries.length > 0 ? '未找到可导入的 txt / docx / pdf 文件' : '没有可导入的语料文件',
        skippedCount: skippedEntries.length,
        skippedEntries: skippedEntries.slice(0, 20)
      }
    }

    const folderSnapshot = await storage.listLibrary('all')
    const folderNameToId = new Map(
      (folderSnapshot?.folders || [])
        .map(folder => [String(folder?.name || ''), String(folder?.id || '')])
        .filter(([name, id]) => name && id)
    )

    const ensureFolderIdByName = async folderName => {
      const normalizedFolderName = String(folderName || '').trim()
      if (!normalizedFolderName) return folderId
      const existingFolderId = folderNameToId.get(normalizedFolderName)
      if (existingFolderId) return existingFolderId
      const createResult = await storage.createFolder(normalizedFolderName)
      if (createResult?.success && createResult.folder?.id) {
        folderNameToId.set(normalizedFolderName, createResult.folder.id)
        return createResult.folder.id
      }
      return folderId
    }

    const importedCorpusItems = []
    const importSkippedEntries = [...skippedEntries]
    const preflightWarningEntries = []

    for (const entry of collectedEntries) {
      try {
        const preflight = await runPreflightCheck(entry.sourcePath)
        if (!preflight.ok) {
          importSkippedEntries.push({
            sourcePath: entry.sourcePath,
            reason: preflight.errors[0] || '导入前体检未通过'
          })
          continue
        }
        if (preflight.warnings.length > 0) {
          preflightWarningEntries.push({
            sourcePath: entry.sourcePath,
            warnings: preflight.warnings
          })
        }

        const { content, encoding } = await readCorpusFile(entry.sourcePath)
        const hierarchyFolderName = preserveHierarchy && entry.rootLabel
          ? buildHierarchyFolderName(entry.rootLabel, entry.relativeDir, path)
          : ''
        const targetFolderId = hierarchyFolderName
          ? await ensureFolderIdByName(hierarchyFolderName)
          : folderId
        const savedRecord = await storage.importCorpus({
          originalName: path.basename(entry.sourcePath),
          sourceType: getSourceTypeFromExtension(entry.extension),
          content,
          folderId: targetFolderId
        })

        importedCorpusItems.push({
          id: savedRecord.meta.id,
          name: savedRecord.meta.name,
          folderId: savedRecord.meta.folderId,
          folderName: savedRecord.meta.folderName,
          filePath: savedRecord.filePath,
          sourcePath: entry.sourcePath,
          sourceEncoding: encoding,
          preflightWarnings: preflight.warnings
        })
      } catch (error) {
        importSkippedEntries.push({
          sourcePath: entry.sourcePath,
          reason: error instanceof Error ? error.message : '导入失败'
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

    const openResult = importedCorpusItems.length === 1
      ? await storage.openCorpus(importedCorpusItems[0].id)
      : await storage.openCorpora(importedCorpusItems.map(item => item.id))

    return {
      ...openResult,
      importedCount: importedCorpusItems.length,
      skippedCount: importSkippedEntries.length,
      skippedEntries: importSkippedEntries.slice(0, 20),
      importedItems: importedCorpusItems,
      preflightWarningEntries: preflightWarningEntries.slice(0, 20),
      preflightWarningCount: preflightWarningEntries.reduce((sum, item) => sum + item.warnings.length, 0)
    }
  }

  async function handleMethod(method, params = {}) {
    if (method === ENGINE_METHODS.appGetInfo) {
      return buildAppInfo({ userDataDir, pendingLaunchFilePaths })
    }
    if (method === ENGINE_METHODS.appGetPendingLaunchFiles) {
      return {
        success: true,
        filePaths: pendingLaunchFilePaths
      }
    }
    if (method === ENGINE_METHODS.appConsumeCrashRecoveryState) {
      return {
        success: true,
        recoveryState: await diagnosticsController.consumeCrashRecoveryState()
      }
    }
    if (method === ENGINE_METHODS.libraryList) {
      return (await ensureStorageReady()).listLibrary(String(params?.folderId || 'all').trim() || 'all')
    }
    if (method === ENGINE_METHODS.libraryOpenQuickPath) {
      return libraryOpenQuickPath(params)
    }
    if (method === ENGINE_METHODS.libraryImportPaths) {
      return libraryImportPaths(params)
    }
    if (method === ENGINE_METHODS.libraryOpenSaved) {
      return (await ensureStorageReady()).openCorpus(normalizeIdentifier(params?.corpusId, { fieldName: '语料 ID' }))
    }
    if (method === ENGINE_METHODS.libraryOpenSavedBatch) {
      const corpusIds = Array.isArray(params?.corpusIds)
        ? params.corpusIds.map(item => normalizeIdentifier(item, { fieldName: '语料 ID' }))
        : []
      return (await ensureStorageReady()).openCorpora(corpusIds)
    }
    if (method === ENGINE_METHODS.libraryRenameCorpus) {
      return (await ensureStorageReady()).renameCorpus(
        normalizeIdentifier(params?.corpusId, { fieldName: '语料 ID' }),
        normalizeTextInput(params?.newName, { maxLength: 120 })
      )
    }
    if (method === ENGINE_METHODS.libraryMoveCorpus) {
      return (await ensureStorageReady()).moveCorpus(
        normalizeIdentifier(params?.corpusId, { fieldName: '语料 ID' }),
        normalizeIdentifier(params?.targetFolderId, {
          fieldName: '目标文件夹 ID',
          allowEmpty: true
        }) || ''
      )
    }
    if (method === ENGINE_METHODS.libraryDeleteCorpus) {
      return (await ensureStorageReady()).deleteCorpus(normalizeIdentifier(params?.corpusId, { fieldName: '语料 ID' }))
    }
    if (method === ENGINE_METHODS.libraryCreateFolder) {
      return (await ensureStorageReady()).createFolder(normalizeTextInput(params?.folderName, { maxLength: 80 }))
    }
    if (method === ENGINE_METHODS.libraryRenameFolder) {
      return (await ensureStorageReady()).renameFolder(
        normalizeIdentifier(params?.folderId, { fieldName: '文件夹 ID' }),
        normalizeTextInput(params?.newName, { maxLength: 80 })
      )
    }
    if (method === ENGINE_METHODS.libraryDeleteFolder) {
      return (await ensureStorageReady()).deleteFolder(
        normalizeIdentifier(params?.folderId, { fieldName: '文件夹 ID' })
      )
    }
    if (method === ENGINE_METHODS.libraryListRecycleBin) {
      return (await ensureStorageReady()).listRecycleBin()
    }
    if (method === ENGINE_METHODS.libraryRestoreRecycleEntry) {
      return (await ensureStorageReady()).restoreRecycleEntry(
        normalizeIdentifier(params?.recycleEntryId, { fieldName: '回收站条目 ID' })
      )
    }
    if (method === ENGINE_METHODS.libraryPurgeRecycleEntry) {
      return (await ensureStorageReady()).purgeRecycleEntry(
        normalizeIdentifier(params?.recycleEntryId, { fieldName: '回收站条目 ID' })
      )
    }
    if (method === ENGINE_METHODS.libraryBackup) {
      return (await ensureStorageReady()).backupLibrary(path.resolve(String(params?.destinationPath || '').trim()))
    }
    if (method === ENGINE_METHODS.libraryRestore) {
      return (await ensureStorageReady()).restoreLibrary(path.resolve(String(params?.sourcePath || '').trim()))
    }
    if (method === ENGINE_METHODS.libraryRepair) {
      return (await ensureStorageReady()).repairLibrary()
    }
    if (method === ENGINE_METHODS.librarySearchKwic) {
      return (await ensureStorageReady()).searchLibraryKWIC({
        folderId: String(params?.folderId || 'all').trim() || 'all',
        keyword: normalizeTextInput(params?.keyword, { fallback: '', maxLength: 320 }),
        leftWindowSize: Number(params?.leftWindowSize),
        rightWindowSize: Number(params?.rightWindowSize),
        searchOptions: params?.searchOptions && typeof params.searchOptions === 'object' ? params.searchOptions : {}
      })
    }
    if (method === ENGINE_METHODS.workspaceGetState) {
      return {
        success: true,
        snapshot: await workspaceStore.getWorkspaceState()
      }
    }
    if (method === ENGINE_METHODS.workspaceSaveState) {
      return {
        success: true,
        snapshot: await workspaceStore.saveWorkspaceState(params?.snapshot || {})
      }
    }
    if (method === ENGINE_METHODS.workspaceGetRecentOpen) {
      return {
        success: true,
        entries: await workspaceStore.getRecentOpen()
      }
    }
    if (method === ENGINE_METHODS.workspaceSaveRecentOpen) {
      return {
        success: true,
        entries: await workspaceStore.saveRecentOpen(params?.entries || [])
      }
    }
    if (method === ENGINE_METHODS.workspaceGetUiSettings) {
      return {
        success: true,
        settings: await workspaceStore.getUiSettings()
      }
    }
    if (method === ENGINE_METHODS.workspaceSaveUiSettings) {
      return {
        success: true,
        settings: await workspaceStore.saveUiSettings(params?.settings || {})
      }
    }
    if (method === ENGINE_METHODS.workspaceGetOnboarding) {
      return {
        success: true,
        onboarding: await workspaceStore.getOnboardingState()
      }
    }
    if (method === ENGINE_METHODS.workspaceSaveOnboarding) {
      return {
        success: true,
        onboarding: await workspaceStore.saveOnboardingState(params?.state || {})
      }
    }
    if (method === ENGINE_METHODS.diagnosticsGetState) {
      return {
        success: true,
        diagnostics: diagnosticsController.getSnapshot()
      }
    }
    if (method === ENGINE_METHODS.diagnosticsWriteLog) {
      diagnosticsController.log(
        normalizeTextInput(params?.level, { fallback: 'info', maxLength: 16 }),
        normalizeTextInput(params?.scope, { fallback: 'native', maxLength: 80 }),
        normalizeTextInput(params?.message, { fallback: '', maxLength: 600 }),
        params?.details ?? null
      )
      emitter.emit('notification', {
        method: ENGINE_EVENTS.diagnosticsLog,
        params: {
          level: params?.level || 'info',
          scope: params?.scope || 'native',
          message: params?.message || ''
        }
      })
      return { success: true }
    }
    if (method === ENGINE_METHODS.diagnosticsExportReport) {
      return diagnosticsController.exportReport(params?.targetPath || '', params?.rendererState || {})
    }
    if (method === ENGINE_METHODS.diagnosticsGetGitHubIssueUrl) {
      return {
        success: true,
        issueUrl: diagnosticsController.getGitHubIssueUrl(
          params?.rendererState || {},
          normalizeTextInput(params?.issueTitle, { fallback: '[Bug] 请简要描述问题', maxLength: 120 })
        ) || ''
      }
    }
    if (method === ENGINE_METHODS.updateGetState) {
      return {
        success: true,
        supported: false,
        updateState: null,
        message: 'Windows 原生更新链尚未接入。'
      }
    }
    if (method === ENGINE_METHODS.updateCheck || method === ENGINE_METHODS.updateInstall) {
      return {
        success: false,
        supported: false,
        message: 'Windows 原生更新链尚未接入。'
      }
    }
    if (method === ENGINE_METHODS.analysisStartTask) {
      return {
        success: true,
        ...(analysisTaskRunner.startTask(String(params?.taskType || ''), params?.payload || {}))
      }
    }
    if (method === ENGINE_METHODS.analysisCancelTask) {
      const task = await analysisTaskRunner.cancelTask(String(params?.taskId || ''))
      if (!task) {
        return {
          success: false,
          message: '找不到分析任务'
        }
      }
      return {
        success: true,
        task
      }
    }
    if (method === ENGINE_METHODS.analysisGetTaskState) {
      const task = analysisTaskRunner.getTaskState(String(params?.taskId || ''))
      if (!task) {
        return {
          success: false,
          message: '找不到分析任务'
        }
      }
      return {
        success: true,
        task
      }
    }
    if (method === ENGINE_METHODS.engineShutdown) {
      return {
        success: true,
        shuttingDown: true
      }
    }

    throw Object.assign(new Error(`Method not found: ${method}`), {
      code: ENGINE_ERROR_CODES.methodNotFound
    })
  }

  return {
    onNotification(listener) {
      emitter.on('notification', listener)
      return () => emitter.off('notification', listener)
    },
    async handleRequest(request = {}) {
      const id = request?.id ?? null
      const method = String(request?.method || '').trim()
      if (request?.jsonrpc !== JSON_RPC_VERSION || !method) {
        return {
          jsonrpc: JSON_RPC_VERSION,
          id,
          error: {
            code: ENGINE_ERROR_CODES.invalidRequest,
            message: 'Invalid JSON-RPC request.'
          }
        }
      }

      try {
        const result = await handleMethod(method, request.params || {})
        return {
          jsonrpc: JSON_RPC_VERSION,
          id,
          result
        }
      } catch (error) {
        diagnosticsController.captureError('engine.host', error, {
          method
        })
        return {
          jsonrpc: JSON_RPC_VERSION,
          id,
          error: {
            code: Number(error?.code) || ENGINE_ERROR_CODES.internalError,
            message: error instanceof Error ? error.message : String(error || 'Internal error')
          }
        }
      }
    },
    async dispose() {
      unsubscribeTasks?.()
      await analysisTaskRunner.dispose()
    }
  }
}
