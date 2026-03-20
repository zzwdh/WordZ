const path = require('path')

function readJsonArrayEnv(name, env = process.env, logger = console) {
  const rawValue = env[name]
  if (!rawValue) return null

  try {
    const parsedValue = JSON.parse(rawValue)
    return Array.isArray(parsedValue) ? [...parsedValue] : null
  } catch (error) {
    logger.warn?.(`[${name}] 解析失败`, error)
    return null
  }
}

function normalizeOptionalPathEnv(name, env = process.env) {
  const rawValue = String(env[name] || '').trim()
  return rawValue ? path.resolve(rawValue) : ''
}

function takeQueueItem(queue, label) {
  if (!queue) return null
  if (queue.length === 0) {
    throw new Error(`测试 ${label} 对话框队列已耗尽`)
  }
  return queue.shift()
}

function resolveOpenDialogResult(queuedItem) {
  if (
    queuedItem &&
    typeof queuedItem === 'object' &&
    !Array.isArray(queuedItem) &&
    queuedItem.canceled
  ) {
    return {
      canceled: true,
      filePaths: []
    }
  }

  const filePaths = Array.isArray(queuedItem) ? queuedItem.map(item => String(item)) : [String(queuedItem)]
  return {
    canceled: false,
    filePaths
  }
}

function resolveSaveDialogResult(queuedItem) {
  if (
    queuedItem &&
    typeof queuedItem === 'object' &&
    !Array.isArray(queuedItem) &&
    queuedItem.canceled
  ) {
    return {
      canceled: true,
      filePath: ''
    }
  }

  return {
    canceled: false,
    filePath: String(queuedItem)
  }
}

function createDialogController({ dialog, openQueue = null, saveQueue = null }) {
  return {
    async showOpenDialog(options) {
      const queuedItem = takeQueueItem(openQueue, '打开')
      if (queuedItem !== null) {
        return resolveOpenDialogResult(queuedItem)
      }
      return dialog.showOpenDialog(options)
    },
    async showSaveDialog(options) {
      const queuedItem = takeQueueItem(saveQueue, '保存')
      if (queuedItem !== null) {
        return resolveSaveDialogResult(queuedItem)
      }
      return dialog.showSaveDialog(options)
    }
  }
}

module.exports = {
  createDialogController,
  normalizeOptionalPathEnv,
  readJsonArrayEnv
}
