const fs = require('fs/promises')
const path = require('path')
const {
  buildDefaultExportPath,
  buildGitHubIssueUrl,
  createSessionId,
  formatTimestamp,
  renderDiagnosticReport,
  sanitizeDiagnosticValue,
  serializeError,
  truncateText
} = require('./format')

const MAX_RECENT_EVENTS = 160
const MAX_RECENT_ERRORS = 16
const MAX_SUMMARY_EVENTS = 30

function createDiagnosticsController({ app, packageManifest = {}, logger = console }) {
  const appName = packageManifest.productName || packageManifest.name || app?.getName?.() || 'WordZ'
  const appVersion = typeof app?.getVersion === 'function' ? app.getVersion() : String(packageManifest.version || '')
  const sessionId = createSessionId()
  const diagnosticsDir = path.join(app?.getPath?.('userData') || process.cwd(), 'diagnostics')
  const crashMarkerPath = path.join(diagnosticsDir, 'crash-recovery.json')
  let recentEvents = []
  let recentErrors = []
  let debugLoggingEnabled = false
  let logFilePath = ''
  let lastExportPath = ''
  let lastGitHubIssueUrl = ''
  let writeQueue = Promise.resolve()

  function getAppInfo() {
    return {
      name: appName,
      version: appVersion,
      help: Array.isArray(packageManifest?.wordz?.help) ? packageManifest.wordz.help : []
    }
  }

  function appendEvent(event) {
    recentEvents = [event, ...recentEvents].slice(0, MAX_RECENT_EVENTS)
    if (event.level === 'error') {
      recentErrors = [event, ...recentErrors].slice(0, MAX_RECENT_ERRORS)
    }
  }

  async function ensureLogFile() {
    if (logFilePath) return logFilePath
    await fs.mkdir(diagnosticsDir, { recursive: true })
    logFilePath = path.join(diagnosticsDir, `session-${sessionId}.log`)
    await fs.appendFile(logFilePath, `# ${appName} diagnostics session ${sessionId}\n`, 'utf8')
    return logFilePath
  }

  function enqueueLogWrite(line) {
    writeQueue = writeQueue
      .then(async () => {
        if (!debugLoggingEnabled) return
        const targetPath = await ensureLogFile()
        await fs.appendFile(targetPath, `${line}\n`, 'utf8')
      })
      .catch(error => {
        logger.warn?.('[diagnostics.write]', error)
      })
    return writeQueue
  }

  function log(level, scope, message, details = null) {
    const event = {
      timestamp: formatTimestamp(),
      level: String(level || 'info').trim() || 'info',
      scope: truncateText(scope || 'app', 80),
      message: truncateText(message || '', 600),
      details: sanitizeDiagnosticValue(details)
    }
    appendEvent(event)
    if (debugLoggingEnabled) {
      void enqueueLogWrite(JSON.stringify(event))
    }
    return event
  }

  function captureError(source, error, details = null) {
    const serializedError = serializeError(error)
    return log('error', source, serializedError.message || '未知错误', {
      ...sanitizeDiagnosticValue(details),
      error: serializedError
    })
  }

  function setDebugLoggingEnabled(enabled) {
    const nextValue = Boolean(enabled)
    if (debugLoggingEnabled === nextValue) return getSnapshot()
    debugLoggingEnabled = nextValue
    log('info', 'diagnostics', nextValue ? '已开启调试日志记录。' : '已关闭调试日志记录。')
    return getSnapshot()
  }

  function getSnapshot() {
    return {
      sessionId,
      appName,
      appVersion,
      startedAt: sessionId,
      platform: process.platform,
      arch: process.arch,
      nodeVersion: process.versions.node || '',
      electronVersion: process.versions.electron || '',
      chromeVersion: process.versions.chrome || '',
      debugLoggingEnabled,
      diagnosticsDir,
      logFilePath,
      lastExportPath,
      lastGitHubIssueUrl,
      recentErrors: recentErrors.slice(0, MAX_RECENT_ERRORS),
      recentEvents: recentEvents.slice(0, MAX_SUMMARY_EVENTS)
    }
  }

  async function exportReport(targetPath, rendererState = {}) {
    const reportContent = renderDiagnosticReport({
      packageManifest,
      appInfo: getAppInfo(),
      snapshot: getSnapshot(),
      rendererState
    })
    const outputPath = targetPath || buildDefaultExportPath(diagnosticsDir, appName, sessionId)
    await fs.mkdir(path.dirname(outputPath), { recursive: true })
    await fs.writeFile(outputPath, reportContent, 'utf8')
    lastExportPath = outputPath
    log('info', 'diagnostics', '已导出诊断报告。', { filePath: outputPath })
    return {
      success: true,
      filePath: outputPath
    }
  }

  function getGitHubIssueUrl(rendererState = {}, issueTitle = '') {
    const url = buildGitHubIssueUrl({
      packageManifest,
      appInfo: getAppInfo(),
      snapshot: getSnapshot(),
      rendererState,
      issueTitle
    })
    if (url) {
      lastGitHubIssueUrl = url
      log('info', 'diagnostics', '已生成 GitHub 反馈链接。', { issueTitle: issueTitle || '[Bug]' })
    }
    return url
  }

  async function markCrashRecoveryState(source, error, details = null) {
    const serializedError = serializeError(error)
    const payload = {
      sessionId,
      recordedAt: formatTimestamp(),
      source: truncateText(source || 'unknown', 120),
      error: serializedError,
      details: sanitizeDiagnosticValue(details)
    }

    try {
      await fs.mkdir(diagnosticsDir, { recursive: true })
      await fs.writeFile(crashMarkerPath, JSON.stringify(payload, null, 2), 'utf8')
    } catch (writeError) {
      logger.warn?.('[diagnostics.crash-marker.write]', writeError)
    }

    return payload
  }

  async function consumeCrashRecoveryState() {
    try {
      const content = await fs.readFile(crashMarkerPath, 'utf8')
      const payload = JSON.parse(content)
      await fs.rm(crashMarkerPath, { force: true })
      return payload && typeof payload === 'object' ? payload : null
    } catch {
      return null
    }
  }

  return {
    captureError,
    exportReport,
    getGitHubIssueUrl,
    getSnapshot,
    log,
    markCrashRecoveryState,
    consumeCrashRecoveryState,
    setDebugLoggingEnabled
  }
}

module.exports = {
  createDiagnosticsController
}
