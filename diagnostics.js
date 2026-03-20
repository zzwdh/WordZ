const fs = require('fs/promises')
const path = require('path')

const MAX_RECENT_EVENTS = 160
const MAX_RECENT_ERRORS = 16
const MAX_SUMMARY_EVENTS = 30
const MAX_STRING_LENGTH = 500
const MAX_EVENT_DETAILS_LENGTH = 6000

function normalizeText(value, fallback = '') {
  return String(value ?? fallback).trim()
}

function truncateText(value, maxLength = MAX_STRING_LENGTH) {
  const text = normalizeText(value)
  if (text.length <= maxLength) return text
  return `${text.slice(0, Math.max(0, maxLength - 1))}…`
}

function parseGitHubRepository(repository) {
  const rawValue =
    typeof repository === 'string'
      ? repository
      : repository && typeof repository.url === 'string'
        ? repository.url
        : ''
  const normalizedValue = normalizeText(rawValue)
  if (!normalizedValue) return { owner: '', repo: '' }

  const cleanedValue = normalizedValue.replace(/^git\+/, '').replace(/\.git$/i, '').replace(/\/+$/, '')
  const match = cleanedValue.match(
    /^(?:https?:\/\/github\.com\/|ssh:\/\/git@github\.com\/|git@github\.com:|github:)?([^/\s]+)\/([^/\s]+)$/i
  )

  if (!match) return { owner: '', repo: '' }
  return {
    owner: normalizeText(match[1]),
    repo: normalizeText(match[2])
  }
}

function serializeError(error) {
  if (!error) return { name: 'Error', message: '未知错误' }
  if (typeof error === 'string') {
    return { name: 'Error', message: truncateText(error, 1200) }
  }
  if (typeof error === 'object') {
    return {
      name: truncateText(error.name || 'Error', 120),
      message: truncateText(error.message || String(error), 1200),
      stack: truncateText(error.stack || '', 4000)
    }
  }
  return {
    name: 'Error',
    message: truncateText(String(error), 1200)
  }
}

function sanitizeDiagnosticValue(value, depth = 0, seen = new WeakSet()) {
  if (value === null || value === undefined) return value
  if (typeof value === 'string') return truncateText(value)
  if (typeof value === 'number' || typeof value === 'boolean') return value
  if (typeof value === 'bigint') return truncateText(String(value))
  if (typeof value === 'function') return '[Function]'
  if (value instanceof Date) return value.toISOString()
  if (value instanceof Error) return serializeError(value)

  if (depth >= 4) {
    if (Array.isArray(value)) return `[Array(${value.length})]`
    return '[Object]'
  }

  if (typeof value === 'object') {
    if (seen.has(value)) return '[Circular]'
    seen.add(value)

    if (Array.isArray(value)) {
      return value.slice(0, 20).map(item => sanitizeDiagnosticValue(item, depth + 1, seen))
    }

    const result = {}
    const entries = Object.entries(value).slice(0, 20)
    for (const [key, entryValue] of entries) {
      result[truncateText(key, 80)] = sanitizeDiagnosticValue(entryValue, depth + 1, seen)
    }
    return result
  }

  return truncateText(String(value))
}

function summarizeDetails(details) {
  if (!details || (typeof details === 'object' && Object.keys(details).length === 0)) return ''
  try {
    return truncateText(JSON.stringify(sanitizeDiagnosticValue(details), null, 2), MAX_EVENT_DETAILS_LENGTH)
  } catch {
    return ''
  }
}

function formatTimestamp(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value)
  return date.toISOString()
}

function createSessionId(date = new Date()) {
  return formatTimestamp(date)
    .replace(/[-:]/g, '')
    .replace(/\.\d+Z$/, 'Z')
}

function buildDefaultExportPath(diagnosticsDir, appName, sessionId) {
  const normalizedAppName = normalizeText(appName || 'WordZ').replace(/[^\w.-]+/g, '-')
  return path.join(diagnosticsDir, `${normalizedAppName}-diagnostics-${sessionId}.md`)
}

function renderEventLines(events = []) {
  if (!Array.isArray(events) || events.length === 0) return ['- 无']
  return events.map(event => {
    const baseLine = `- [${formatTimestamp(event.timestamp)}] ${event.level || 'info'} / ${event.scope || 'app'}: ${event.message || ''}`
    const detailsText = summarizeDetails(event.details)
    return detailsText ? `${baseLine}\n  ${detailsText.replace(/\n/g, '\n  ')}` : baseLine
  })
}

function buildIssueBody({ appName, appVersion, snapshot, rendererState }) {
  const recentErrorLines = renderEventLines((snapshot?.recentErrors || []).slice(0, 5))
  const rendererSummary = sanitizeDiagnosticValue(rendererState || {})
  const lines = [
    '## 问题描述',
    '请在这里描述你遇到的问题、触发步骤，以及你原本期望看到的结果。',
    '',
    '## 运行环境',
    `- 应用：${appName || 'WordZ'}`,
    `- 版本：${appVersion || '未知'}`,
    `- 平台：${snapshot?.platform || process.platform} ${snapshot?.arch || process.arch}`,
    `- Electron：${snapshot?.electronVersion || process.versions.electron || ''}`,
    `- Node：${snapshot?.nodeVersion || process.versions.node || ''}`,
    `- 会话 ID：${snapshot?.sessionId || ''}`,
    `- 调试日志：${snapshot?.debugLoggingEnabled ? '已开启' : '未开启'}`,
    '',
    '## 当前工作区摘要',
    '```json',
    JSON.stringify(rendererSummary, null, 2),
    '```',
    '',
    '## 最近错误',
    ...recentErrorLines,
    '',
    '## 附加说明',
    '- 如果问题难以复现，建议先在设置里开启“记录调试日志（Debug）”，复现后导出诊断报告并作为附件上传。'
  ]
  return lines.join('\n')
}

function buildGitHubIssueUrl({ packageManifest = {}, appInfo = {}, snapshot = {}, rendererState = {}, issueTitle = '' } = {}) {
  const { owner, repo } = parseGitHubRepository(packageManifest.repository)
  if (!(owner && repo)) return ''

  const baseUrl = `https://github.com/${owner}/${repo}/issues/new`
  const title = truncateText(issueTitle || '[Bug] 请简要描述问题', 120)
  const body = buildIssueBody({
    appName: appInfo.name || packageManifest.productName || packageManifest.name || 'WordZ',
    appVersion: appInfo.version || packageManifest.version || '',
    snapshot,
    rendererState
  })
  const params = new URLSearchParams({
    title,
    body
  })
  return `${baseUrl}?${params.toString()}`
}

function renderDiagnosticReport({ packageManifest = {}, appInfo = {}, snapshot = {}, rendererState = {} } = {}) {
  const appName = appInfo.name || packageManifest.productName || packageManifest.name || 'WordZ'
  const appVersion = appInfo.version || packageManifest.version || ''
  const helpLines = Array.isArray(appInfo.help) && appInfo.help.length > 0
    ? appInfo.help.map(item => `- ${item}`)
    : ['- 无']
  const eventLines = renderEventLines((snapshot.recentEvents || []).slice(0, MAX_SUMMARY_EVENTS))
  const errorLines = renderEventLines((snapshot.recentErrors || []).slice(0, MAX_RECENT_ERRORS))
  const rendererSummary = sanitizeDiagnosticValue(rendererState || {})

  return [
    `# ${appName} 诊断报告`,
    '',
    `生成时间：${formatTimestamp()}`,
    `会话 ID：${snapshot.sessionId || ''}`,
    '',
    '## 应用环境',
    `- 版本：${appVersion || '未知'}`,
    `- 平台：${snapshot.platform || process.platform} ${snapshot.arch || process.arch}`,
    `- Electron：${snapshot.electronVersion || process.versions.electron || ''}`,
    `- Node：${snapshot.nodeVersion || process.versions.node || ''}`,
    `- 调试日志：${snapshot.debugLoggingEnabled ? '已开启' : '未开启'}`,
    `- 会话日志文件：${snapshot.logFilePath || '未生成'}`,
    `- 最近一次导出：${snapshot.lastExportPath || '暂无'}`,
    '',
    '## 当前工作区摘要',
    '```json',
    JSON.stringify(rendererSummary, null, 2),
    '```',
    '',
    '## 最近错误',
    ...errorLines,
    '',
    '## 最近事件',
    ...eventLines,
    '',
    '## 帮助信息',
    ...helpLines,
    ''
  ].join('\n')
}

function createDiagnosticsController({ app, packageManifest = {}, logger = console }) {
  const appName = packageManifest.productName || packageManifest.name || app?.getName?.() || 'WordZ'
  const appVersion = typeof app?.getVersion === 'function' ? app.getVersion() : String(packageManifest.version || '')
  const sessionId = createSessionId()
  const diagnosticsDir = path.join(app?.getPath?.('userData') || process.cwd(), 'diagnostics')
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
      level: normalizeText(level, 'info') || 'info',
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

  return {
    captureError,
    exportReport,
    getGitHubIssueUrl,
    getSnapshot,
    log,
    setDebugLoggingEnabled
  }
}

module.exports = {
  buildGitHubIssueUrl,
  createDiagnosticsController,
  parseGitHubRepository,
  renderDiagnosticReport
}
