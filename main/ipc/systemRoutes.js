function registerSystemIpcRoutes({
  registerSafeIpcHandler,
  fs,
  path,
  getExcelJS,
  app,
  packageManifest,
  getAppInfo,
  showSaveDialogForApp,
  normalizeTextInput,
  normalizeTableRows,
  normalizeBooleanInput,
  normalizeExternalUrlInput,
  normalizeFilePathInput,
  pathExists,
  showItemInSystemFileManager,
  getSystemNotificationController,
  getWindowProgressController,
  getWindowAttentionController,
  isSmokeEnv,
  getPackagedSmokeConfig,
  writePackagedSmokeResult,
  getSmokeObserverState,
  markSystemOpenBridgeReady,
  consumePendingSystemOpenFilePaths,
  getAutoUpdateController,
  getDiagnosticsController,
  getAnalysisCacheController,
  shell
}) {
  registerSafeIpcHandler('save-table-file', async (event, { defaultBaseName, rows } = {}) => {
    const normalizedBaseName = normalizeTextInput(defaultBaseName, {
      fallback: '导出结果',
      maxLength: 120
    })
    const normalizedRows = normalizeTableRows(rows)

    const result = await showSaveDialogForApp({
      defaultPath: `${normalizedBaseName || '导出结果'}.xlsx`,
      filters: [
        { name: 'Excel 工作簿', extensions: ['xlsx'] },
        { name: 'CSV 文件', extensions: ['csv'] }
      ]
    })

    if (result.canceled || !result.filePath) {
      return {
        success: false,
        canceled: true,
        message: '用户取消了保存'
      }
    }

    const outputPath = result.filePath
    const ext = path.extname(outputPath).toLowerCase()

    if (normalizedRows.length === 0) {
      return {
        success: false,
        message: '没有可导出的表格数据'
      }
    }

    if (ext === '.csv') {
      const csvLines = normalizedRows.map(row =>
        row
          .map(value => {
            const text = String(value ?? '')
            return '"' + text.replace(/"/g, '""') + '"'
          })
          .join(',')
      )

      await fs.writeFile(outputPath, '\uFEFF' + csvLines.join('\r\n'), 'utf8')

      return {
        success: true,
        filePath: outputPath
      }
    }

    const ExcelJS = getExcelJS()
    const workbook = new ExcelJS.Workbook()
    const worksheet = workbook.addWorksheet('Sheet1')
    worksheet.addRows(normalizedRows)
    await workbook.xlsx.writeFile(outputPath)

    return {
      success: true,
      filePath: outputPath
    }
  })

  registerSafeIpcHandler('get-app-info', async () => {
    return {
      success: true,
      appInfo: getAppInfo({
        app,
        packageManifest,
        autoUpdateController: getAutoUpdateController()
      })
    }
  })

  registerSafeIpcHandler('show-system-notification', async (event, payload = {}) => {
    return getSystemNotificationController()?.showNotification?.(payload) || {
      success: false,
      supported: false,
      message: '当前系统通知不可用。'
    }
  })

  registerSafeIpcHandler('set-window-progress-state', async (event, payload = {}) => {
    const source = normalizeTextInput(payload?.source, { fallback: '', maxLength: 40 })
    const state = normalizeTextInput(payload?.state, { fallback: 'none', maxLength: 20 })
    const progress = Number(payload?.progress)
    const priority = Number(payload?.priority)

    if (!source) {
      return {
        success: false,
        message: '缺少进度来源标识。'
      }
    }

    const windowProgressController = getWindowProgressController()
    if (!windowProgressController) {
      return {
        success: false,
        message: '当前窗口进度条不可用。'
      }
    }

    if (state === 'none') {
      windowProgressController.clearSource(source)
    } else {
      windowProgressController.updateSource(source, {
        state,
        progress: Number.isFinite(progress) ? progress : 0,
        priority: Number.isFinite(priority) ? priority : 0
      })
    }

    return {
      success: true
    }
  })

  registerSafeIpcHandler('set-window-attention-state', async (event, payload = {}) => {
    const source = normalizeTextInput(payload?.source, { fallback: '', maxLength: 40 })
    const state = normalizeTextInput(payload?.state, { fallback: '', maxLength: 20 })
    const description = normalizeTextInput(payload?.description, { fallback: '', maxLength: 120 })
    const count = Number(payload?.count)
    const priority = Number(payload?.priority)
    const requestAttention = normalizeBooleanInput(payload?.requestAttention)

    if (!source) {
      return {
        success: false,
        message: '缺少提醒来源标识。'
      }
    }

    const windowAttentionController = getWindowAttentionController()
    if (!windowAttentionController) {
      return {
        success: false,
        message: '当前窗口提醒能力不可用。'
      }
    }

    if (state === 'none' || !Number.isFinite(count) || count <= 0) {
      windowAttentionController.clearSource(source)
    } else {
      windowAttentionController.updateSource(source, {
        count,
        description,
        priority: Number.isFinite(priority) ? priority : 0,
        requestAttention
      })
    }

    return {
      success: true
    }
  })

  registerSafeIpcHandler('get-smoke-observer-state', async () => {
    if (!isSmokeEnv) {
      return {
        success: false,
        message: '当前不是 smoke 测试环境。'
      }
    }

    return {
      success: true,
      state: getSmokeObserverState()
    }
  })

  registerSafeIpcHandler('get-packaged-smoke-config', async () => {
    if (!isSmokeEnv) {
      return {
        success: false,
        message: '当前不是 smoke 测试环境。'
      }
    }

    return {
      success: true,
      config: getPackagedSmokeConfig?.() || {
        enabled: false,
        autoRun: false
      }
    }
  })

  registerSafeIpcHandler('report-packaged-smoke-result', async (event, payload = {}) => {
    if (!isSmokeEnv) {
      return {
        success: false,
        message: '当前不是 smoke 测试环境。'
      }
    }

    const status = normalizeTextInput(payload?.status, { fallback: '', maxLength: 24 })
    const stage = normalizeTextInput(payload?.stage, { fallback: '', maxLength: 80 })
    const message = normalizeTextInput(payload?.message, { fallback: '', maxLength: 600 })
    const corpusName = normalizeTextInput(payload?.corpusName, { fallback: '', maxLength: 160 })
    const statsRowCount = Number(payload?.statsRowCount)
    const kwicResultCount = Number(payload?.kwicResultCount)
    const runtime = payload?.runtime && typeof payload.runtime === 'object'
      ? {
          analysisMode: normalizeTextInput(payload.runtime.analysisMode, { fallback: '', maxLength: 24 }),
          searchQuery: normalizeTextInput(payload.runtime.searchQuery, { fallback: '', maxLength: 160 })
        }
      : null

    return writePackagedSmokeResult?.({
      status,
      stage,
      message,
      corpusName,
      statsRowCount: Number.isFinite(statsRowCount) ? statsRowCount : 0,
      kwicResultCount: Number.isFinite(kwicResultCount) ? kwicResultCount : 0,
      runtime
    }) || {
      success: false,
      message: 'packaged smoke 结果写入器不可用。'
    }
  })

  registerSafeIpcHandler('consume-pending-system-open-files', async () => {
    markSystemOpenBridgeReady()
    return {
      success: true,
      filePaths: consumePendingSystemOpenFilePaths()
    }
  })

  registerSafeIpcHandler('get-auto-update-state', async () => {
    return {
      success: true,
      updateState: getAutoUpdateController()?.getStatusSnapshot?.() || null
    }
  })

  registerSafeIpcHandler('check-for-updates', async () => {
    return getAutoUpdateController()?.checkForUpdates?.() || {
      success: false,
      disabled: true,
      message: '自动更新当前不可用。'
    }
  })

  registerSafeIpcHandler('install-downloaded-update', async () => {
    return getAutoUpdateController()?.quitAndInstall?.() || {
      success: false,
      message: '当前没有已下载完成的更新。'
    }
  })

  registerSafeIpcHandler('get-diagnostic-state', async () => {
    return {
      success: true,
      diagnostics: getDiagnosticsController()?.getSnapshot?.() || null
    }
  })

  registerSafeIpcHandler('set-diagnostic-logging-enabled', async (event, enabled) => {
    const diagnostics = getDiagnosticsController()?.setDebugLoggingEnabled?.(normalizeBooleanInput(enabled)) || null
    return {
      success: true,
      diagnostics
    }
  })

  registerSafeIpcHandler('write-diagnostic-log', async (event, payload = {}) => {
    getDiagnosticsController()?.log?.(
      normalizeTextInput(payload?.level, { fallback: 'info', maxLength: 16 }),
      normalizeTextInput(payload?.scope, { fallback: 'renderer', maxLength: 80 }),
      normalizeTextInput(payload?.message, { fallback: '', maxLength: 600 }),
      payload?.details ?? null
    )
    return {
      success: true
    }
  })

  registerSafeIpcHandler('export-diagnostic-report', async (event, rendererState = {}) => {
    const diagnosticsController = getDiagnosticsController()
    const snapshot = diagnosticsController?.getSnapshot?.() || {}
    const defaultPath = path.join(
      snapshot.diagnosticsDir || path.join(app.getPath('userData'), 'diagnostics'),
      `WordZ-diagnostics-${snapshot.sessionId || Date.now()}.md`
    )
    const result = await showSaveDialogForApp({
      defaultPath,
      filters: [{ name: 'Markdown 文件', extensions: ['md'] }, { name: '文本文件', extensions: ['txt'] }]
    })

    if (result.canceled || !result.filePath) {
      return {
        success: false,
        canceled: true,
        message: '用户取消了诊断报告导出'
      }
    }

    const exportResult = await diagnosticsController.exportReport(result.filePath, rendererState)
    return {
      success: true,
      filePath: exportResult.filePath
    }
  })

  registerSafeIpcHandler('export-diagnostic-report-auto', async (event, rendererState = {}) => {
    const diagnosticsController = getDiagnosticsController()
    const snapshot = diagnosticsController?.getSnapshot?.() || {}
    const defaultPath = path.join(
      snapshot.diagnosticsDir || path.join(app.getPath('userData'), 'diagnostics'),
      `WordZ-diagnostics-auto-${Date.now()}.md`
    )
    const exportResult = await diagnosticsController.exportReport(defaultPath, rendererState)
    return {
      success: true,
      filePath: exportResult.filePath
    }
  })

  registerSafeIpcHandler('analysis-cache-get', async (event, payload = {}) => {
    const cacheKey = normalizeTextInput(payload?.cacheKey, { fallback: '', maxLength: 320 })
    if (!cacheKey) {
      return {
        success: false,
        message: '缓存键不能为空'
      }
    }
    return getAnalysisCacheController()?.get?.(cacheKey) || {
      success: false,
      message: '分析缓存控制器不可用。'
    }
  })

  registerSafeIpcHandler('analysis-cache-set', async (event, payload = {}) => {
    const cacheKey = normalizeTextInput(payload?.cacheKey, { fallback: '', maxLength: 320 })
    if (!cacheKey) {
      return {
        success: false,
        message: '缓存键不能为空'
      }
    }
    return getAnalysisCacheController()?.set?.(cacheKey, payload?.entry ?? null) || {
      success: false,
      message: '分析缓存控制器不可用。'
    }
  })

  registerSafeIpcHandler('analysis-cache-delete', async (event, payload = {}) => {
    const cacheKey = normalizeTextInput(payload?.cacheKey, { fallback: '', maxLength: 320 })
    if (!cacheKey) {
      return {
        success: false,
        message: '缓存键不能为空'
      }
    }
    return getAnalysisCacheController()?.remove?.(cacheKey) || {
      success: false,
      message: '分析缓存控制器不可用。'
    }
  })

  registerSafeIpcHandler('analysis-cache-clear', async () => {
    return getAnalysisCacheController()?.clear?.() || {
      success: false,
      message: '分析缓存控制器不可用。'
    }
  })

  registerSafeIpcHandler('analysis-cache-state', async () => {
    return getAnalysisCacheController()?.getState?.() || {
      success: false,
      message: '分析缓存控制器不可用。'
    }
  })

  registerSafeIpcHandler('analysis-cache-prune', async () => {
    return getAnalysisCacheController()?.prune?.() || {
      success: false,
      message: '分析缓存控制器不可用。'
    }
  })

  registerSafeIpcHandler('open-github-feedback', async (event, payload = {}) => {
    const diagnosticsController = getDiagnosticsController()
    const issueUrl = diagnosticsController?.getGitHubIssueUrl?.(
      payload?.rendererState ?? {},
      normalizeTextInput(payload?.issueTitle, { fallback: '[Bug] 请简要描述问题', maxLength: 120 })
    ) || ''

    if (!issueUrl) {
      return {
        success: false,
        message: '当前仓库未配置可用的 GitHub Issues 地址。'
      }
    }

    await shell.openExternal(issueUrl)
    return {
      success: true,
      issueUrl
    }
  })

  registerSafeIpcHandler('open-external-url', async (event, rawUrl) => {
    const externalUrl = normalizeExternalUrlInput(rawUrl)
    await shell.openExternal(externalUrl)
    return {
      success: true,
      url: externalUrl
    }
  })

  registerSafeIpcHandler('show-path-in-folder', async (event, rawPath) => {
    const normalizedPath = normalizeFilePathInput(rawPath, { fieldName: '目标路径' })
    if (!(await pathExists(fs, normalizedPath))) {
      return {
        success: false,
        message: '目标路径不存在'
      }
    }

    return showItemInSystemFileManager(normalizedPath, {
      fieldName: '目标路径',
      missingMessage: '目标路径不存在'
    })
  })

  registerSafeIpcHandler('consume-crash-recovery-state', async () => {
    const diagnosticsController = getDiagnosticsController()
    const recoveryState = await diagnosticsController?.consumeCrashRecoveryState?.()
    return {
      success: true,
      recoveryState: recoveryState || null
    }
  })
}

module.exports = {
  registerSystemIpcRoutes
}
