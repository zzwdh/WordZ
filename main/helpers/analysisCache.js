const crypto = require('crypto')
const path = require('path')

const CACHE_SCHEMA_VERSION = 1
const CACHE_FILE_EXTENSION = '.json'
const CACHE_MAX_KEY_LENGTH = 320
const CACHE_MAX_ENTRY_AGE_MS = 1000 * 60 * 60 * 24 * 14 // 14 days
const CACHE_MAX_ENTRY_COUNT = 36
const CACHE_MAX_TOTAL_BYTES = 128 * 1024 * 1024 // 128 MB

function normalizeCacheKey(cacheKey) {
  const normalizedKey = String(cacheKey || '').trim().slice(0, CACHE_MAX_KEY_LENGTH)
  if (!normalizedKey) return ''
  return normalizedKey
}

function getCacheHash(cacheKey) {
  return crypto.createHash('sha256').update(cacheKey).digest('hex')
}

function isCacheFileName(fileName) {
  return String(fileName || '').endsWith(CACHE_FILE_EXTENSION)
}

function createAnalysisCacheController({
  app,
  fs,
  logger = console,
  maxEntryAgeMs = CACHE_MAX_ENTRY_AGE_MS,
  maxEntryCount = CACHE_MAX_ENTRY_COUNT,
  maxTotalBytes = CACHE_MAX_TOTAL_BYTES
}) {
  const cacheDir = path.join(app.getPath('userData'), 'analysis-cache')
  let writeQueue = Promise.resolve()

  async function ensureCacheDir() {
    await fs.mkdir(cacheDir, { recursive: true })
  }

  function getCacheFilePath(cacheKey) {
    return path.join(cacheDir, `${getCacheHash(cacheKey)}${CACHE_FILE_EXTENSION}`)
  }

  async function removeFileIfExists(filePath) {
    try {
      await fs.rm(filePath, { force: true })
    } catch (error) {
      logger.warn?.('[analysis-cache.rm]', error)
    }
  }

  async function listCacheFiles() {
    await ensureCacheDir()
    const entries = await fs.readdir(cacheDir, { withFileTypes: true })
    return entries
      .filter(entry => entry.isFile() && isCacheFileName(entry.name))
      .map(entry => path.join(cacheDir, entry.name))
  }

  async function readCacheFile(filePath) {
    const rawContent = await fs.readFile(filePath, 'utf8')
    const parsed = JSON.parse(rawContent)
    if (!parsed || typeof parsed !== 'object') return null
    return parsed
  }

  async function prune() {
    const filePaths = await listCacheFiles()
    if (filePaths.length === 0) {
      return {
        success: true,
        removedCount: 0,
        remainingCount: 0,
        totalBytes: 0
      }
    }

    const now = Date.now()
    const fileStats = []
    let totalBytes = 0

    for (const filePath of filePaths) {
      try {
        const stat = await fs.stat(filePath)
        if (!stat.isFile()) continue
        const updatedAtMs = Number(stat.mtimeMs) || 0
        const size = Number(stat.size) || 0
        totalBytes += size
        fileStats.push({
          filePath,
          updatedAtMs,
          size,
          expired: maxEntryAgeMs > 0 && now - updatedAtMs > maxEntryAgeMs
        })
      } catch (error) {
        logger.warn?.('[analysis-cache.stat]', error)
      }
    }

    fileStats.sort((a, b) => b.updatedAtMs - a.updatedAtMs)
    const toDelete = new Set(fileStats.filter(item => item.expired).map(item => item.filePath))

    let remainingCount = fileStats.length - toDelete.size
    let remainingBytes = fileStats
      .filter(item => !toDelete.has(item.filePath))
      .reduce((sum, item) => sum + item.size, 0)

    for (let index = fileStats.length - 1; index >= 0; index -= 1) {
      const item = fileStats[index]
      if (toDelete.has(item.filePath)) continue
      const shouldDeleteByCount = maxEntryCount > 0 && remainingCount > maxEntryCount
      const shouldDeleteBySize = maxTotalBytes > 0 && remainingBytes > maxTotalBytes
      if (!(shouldDeleteByCount || shouldDeleteBySize)) continue
      toDelete.add(item.filePath)
      remainingCount -= 1
      remainingBytes -= item.size
    }

    for (const filePath of toDelete) {
      await removeFileIfExists(filePath)
    }

    return {
      success: true,
      removedCount: toDelete.size,
      remainingCount: Math.max(0, remainingCount),
      totalBytes: Math.max(0, remainingBytes)
    }
  }

  async function get(cacheKey) {
    const normalizedKey = normalizeCacheKey(cacheKey)
    if (!normalizedKey) {
      return {
        success: false,
        message: '缓存键不能为空'
      }
    }

    const filePath = getCacheFilePath(normalizedKey)
    try {
      const payload = await readCacheFile(filePath)
      if (!payload || payload.cacheKey !== normalizedKey || payload.schemaVersion !== CACHE_SCHEMA_VERSION) {
        await removeFileIfExists(filePath)
        return {
          success: true,
          hit: false,
          payload: null
        }
      }

      const savedAt = Date.parse(String(payload.savedAt || ''))
      if (Number.isFinite(savedAt) && maxEntryAgeMs > 0 && Date.now() - savedAt > maxEntryAgeMs) {
        await removeFileIfExists(filePath)
        return {
          success: true,
          hit: false,
          payload: null
        }
      }

      return {
        success: true,
        hit: true,
        payload: payload.payload ?? null,
        savedAt: payload.savedAt || ''
      }
    } catch (error) {
      if (error?.code === 'ENOENT') {
        return {
          success: true,
          hit: false,
          payload: null
        }
      }
      logger.warn?.('[analysis-cache.get]', error)
      return {
        success: false,
        message: error?.message || '读取缓存失败'
      }
    }
  }

  async function set(cacheKey, payload) {
    const normalizedKey = normalizeCacheKey(cacheKey)
    if (!normalizedKey) {
      return {
        success: false,
        message: '缓存键不能为空'
      }
    }

    const serialized = JSON.stringify({
      schemaVersion: CACHE_SCHEMA_VERSION,
      cacheKey: normalizedKey,
      savedAt: new Date().toISOString(),
      payload: payload ?? null
    })
    const filePath = getCacheFilePath(normalizedKey)
    const tempPath = `${filePath}.tmp-${process.pid}-${Date.now()}`

    writeQueue = writeQueue
      .then(async () => {
        await ensureCacheDir()
        await fs.writeFile(tempPath, serialized, 'utf8')
        await fs.rename(tempPath, filePath)
        await prune()
      })
      .catch(error => {
        logger.warn?.('[analysis-cache.set]', error)
      })

    await writeQueue
    return {
      success: true,
      bytes: Buffer.byteLength(serialized, 'utf8')
    }
  }

  async function remove(cacheKey) {
    const normalizedKey = normalizeCacheKey(cacheKey)
    if (!normalizedKey) {
      return {
        success: false,
        message: '缓存键不能为空'
      }
    }
    const filePath = getCacheFilePath(normalizedKey)
    await removeFileIfExists(filePath)
    return {
      success: true
    }
  }

  async function clear() {
    const filePaths = await listCacheFiles()
    for (const filePath of filePaths) {
      await removeFileIfExists(filePath)
    }
    return {
      success: true,
      removedCount: filePaths.length
    }
  }

  async function getState() {
    const filePaths = await listCacheFiles()
    let totalBytes = 0
    for (const filePath of filePaths) {
      try {
        const stat = await fs.stat(filePath)
        totalBytes += Number(stat.size) || 0
      } catch {
        // ignore single-file errors
      }
    }
    return {
      success: true,
      cacheDir,
      entryCount: filePaths.length,
      totalBytes,
      maxEntryAgeMs,
      maxEntryCount,
      maxTotalBytes
    }
  }

  return {
    get,
    set,
    remove,
    clear,
    prune,
    getState
  }
}

module.exports = {
  createAnalysisCacheController
}
