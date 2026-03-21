const path = require('path')

const SUPPORTED_CORPUS_EXTENSIONS = new Set(['.txt', '.docx', '.pdf'])
const SUPPORTED_LAUNCH_ACTIONS = new Set([
  'open-quick-corpus',
  'import-and-save-corpus',
  'open-library',
  'open-help-center'
])

function normalizeSupportedCorpusFilePath(rawFilePath) {
  const normalizedValue = String(rawFilePath || '').trim()
  if (!normalizedValue || normalizedValue.startsWith('-')) return ''

  const resolvedPath = path.resolve(normalizedValue)
  const extension = path.extname(resolvedPath).toLowerCase()
  if (!SUPPORTED_CORPUS_EXTENSIONS.has(extension)) return ''
  return resolvedPath
}

function extractLaunchFilePaths(argv = []) {
  if (!Array.isArray(argv)) return []

  const seen = new Set()
  const filePaths = []

  for (const value of argv) {
    const normalizedPath = normalizeSupportedCorpusFilePath(value)
    if (!normalizedPath || seen.has(normalizedPath)) continue
    seen.add(normalizedPath)
    filePaths.push(normalizedPath)
  }

  return filePaths
}

function normalizeLaunchAction(rawAction) {
  const normalizedAction = String(rawAction || '').trim()
  if (!SUPPORTED_LAUNCH_ACTIONS.has(normalizedAction)) return ''
  return normalizedAction
}

function extractLaunchAction(argv = []) {
  if (!Array.isArray(argv)) return ''

  for (let index = 0; index < argv.length; index += 1) {
    const currentArg = String(argv[index] || '').trim()
    if (!currentArg) continue

    if (currentArg.startsWith('--wordz-action=')) {
      const [, actionValue = ''] = currentArg.split('=', 2)
      const normalizedAction = normalizeLaunchAction(actionValue)
      if (normalizedAction) return normalizedAction
      continue
    }

    if (currentArg === '--wordz-action') {
      const nextArg = String(argv[index + 1] || '').trim()
      const normalizedAction = normalizeLaunchAction(nextArg)
      if (normalizedAction) return normalizedAction
    }
  }

  return ''
}

function addRecentDocumentIfSupported(app, filePath, logger = console) {
  const normalizedPath = normalizeSupportedCorpusFilePath(filePath)
  if (!normalizedPath) return false
  if (!['darwin', 'win32'].includes(process.platform)) return false
  if (typeof app?.addRecentDocument !== 'function') return false

  try {
    app.addRecentDocument(normalizedPath)
    return true
  } catch (error) {
    logger.warn?.('[recent-document.add]', error)
    return false
  }
}

function focusWindow(win) {
  if (!win || win.isDestroyed?.()) return false

  if (win.isMinimized?.()) {
    win.restore()
  }
  if (!win.isVisible?.()) {
    win.show()
  }
  win.focus()
  return true
}

module.exports = {
  addRecentDocumentIfSupported,
  extractLaunchAction,
  extractLaunchFilePaths,
  focusWindow,
  normalizeSupportedCorpusFilePath
}
