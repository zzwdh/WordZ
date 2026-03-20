import { RECENT_OPEN_LIMIT } from './constants.mjs'

function getRecentOpenTypeLabel(type) {
  if (type === 'quick') return '外部文件'
  if (type === 'saved-multi') return '多语料'
  return '本地语料'
}

export function normalizeRecentOpenEntry(rawEntry) {
  if (!rawEntry || typeof rawEntry !== 'object') return null
  const type = ['quick', 'saved', 'saved-multi'].includes(rawEntry.type) ? rawEntry.type : ''
  if (!type) return null

  const label = String(rawEntry.label || '').trim()
  if (!label) return null

  const corpusIds = Array.isArray(rawEntry.corpusIds)
    ? rawEntry.corpusIds.map(item => String(item || '').trim()).filter(Boolean)
    : []
  const filePath = String(rawEntry.filePath || '').trim()
  const corpusId = String(rawEntry.corpusId || '').trim()
  const entryKey = String(rawEntry.key || '').trim() || (
    type === 'quick'
      ? `quick:${filePath}`
      : type === 'saved'
        ? `saved:${corpusId}`
        : `saved-multi:${[...corpusIds].sort().join(',')}`
  )

  if (!entryKey) return null
  if (type === 'quick' && !filePath) return null
  if (type === 'saved' && !corpusId) return null
  if (type === 'saved-multi' && corpusIds.length === 0) return null

  return {
    key: entryKey,
    type,
    label,
    detail: String(rawEntry.detail || '').trim(),
    filePath,
    corpusId,
    corpusIds,
    sourceType: String(rawEntry.sourceType || '').trim(),
    openedAt: String(rawEntry.openedAt || '').trim() || new Date().toISOString()
  }
}

export function loadRecentOpenEntries(storage, storageKey) {
  try {
    const rawValue = storage.getItem(storageKey)
    if (!rawValue) return []
    const parsedValue = JSON.parse(rawValue)
    if (!Array.isArray(parsedValue)) return []
    return parsedValue
      .map(normalizeRecentOpenEntry)
      .filter(Boolean)
      .slice(0, RECENT_OPEN_LIMIT)
  } catch (error) {
    console.warn('[recent-open.load]', error)
    return []
  }
}

export function persistRecentOpenEntries(storage, storageKey, entries) {
  try {
    storage.setItem(
      storageKey,
      JSON.stringify(Array.isArray(entries) ? entries.slice(0, RECENT_OPEN_LIMIT) : [])
    )
  } catch (error) {
    console.warn('[recent-open.save]', error)
  }
}

export function renderRecentOpenList(targets, entries) {
  const { section, list, clearButton } = targets || {}
  if (!section || !list) return

  const normalizedEntries = Array.isArray(entries) ? entries : []
  section.classList.toggle('hidden', normalizedEntries.length === 0)
  if (clearButton) clearButton.disabled = normalizedEntries.length === 0

  list.replaceChildren()
  if (normalizedEntries.length === 0) {
    const emptyNode = document.createElement('div')
    emptyNode.className = 'recent-open-empty'
    emptyNode.textContent = '最近打开的语料会显示在这里。'
    list.append(emptyNode)
    return
  }

  normalizedEntries.forEach((entry, index) => {
    const button = document.createElement('button')
    button.className = 'recent-open-item'
    button.type = 'button'
    button.dataset.recentOpenIndex = String(index)

    const head = document.createElement('span')
    head.className = 'recent-open-item-head'

    const title = document.createElement('span')
    title.className = 'recent-open-item-title'
    title.textContent = entry.label

    const badge = document.createElement('span')
    badge.className = 'recent-open-badge'
    badge.textContent = getRecentOpenTypeLabel(entry.type)

    head.append(title, badge)

    const detail = document.createElement('span')
    detail.className = 'recent-open-item-detail'
    detail.textContent = entry.detail || '点击后重新载入该语料'

    button.append(head, detail)
    list.append(button)
  })
}

export function buildRecentOpenEntryFromResult(result) {
  if (!result?.success) return null

  if (result.mode === 'quick') {
    const filePath = String(result.filePath || '').trim()
    if (!filePath) return null
    const sourceLabel = String(result.sourceEncoding || '').trim()
    return {
      key: `quick:${filePath}`,
      type: 'quick',
      label: String(result.displayName || result.fileName || '外部文件').trim(),
      detail: sourceLabel
        ? `${String(result.fileName || filePath).trim()} · ${sourceLabel}`
        : String(result.fileName || filePath).trim(),
      filePath,
      sourceType: String(result.sourceType || '').trim(),
      openedAt: new Date().toISOString()
    }
  }

  if (result.mode === 'saved-multi') {
    const corpusIds = Array.isArray(result.corpusIds)
      ? result.corpusIds.map(item => String(item || '').trim()).filter(Boolean)
      : []
    if (corpusIds.length === 0) return null
    const selectedItems = Array.isArray(result.selectedItems) ? result.selectedItems : []
    const itemNames = selectedItems.map(item => String(item?.name || '').trim()).filter(Boolean)
    const previewNames = itemNames.slice(0, 2).join('、')
    const detailParts = []
    if (previewNames) {
      detailParts.push(itemNames.length > 2 ? `${previewNames} 等 ${itemNames.length} 条语料` : previewNames)
    }
    if (result.folderName) detailParts.push(String(result.folderName).trim())
    return {
      key: `saved-multi:${[...corpusIds].sort().join(',')}`,
      type: 'saved-multi',
      label: String(result.displayName || `已选 ${corpusIds.length} 条语料`).trim(),
      detail: detailParts.join(' · ') || `共 ${corpusIds.length} 条已保存语料`,
      corpusIds,
      openedAt: new Date().toISOString()
    }
  }

  const corpusId = String(result.corpusId || '').trim()
  if (!corpusId) return null
  const detailParts = []
  if (result.folderName) detailParts.push(String(result.folderName).trim())
  if (result.sourceEncoding) detailParts.push(String(result.sourceEncoding).trim())
  return {
    key: `saved:${corpusId}`,
    type: 'saved',
    label: String(result.displayName || result.fileName || '已保存语料').trim(),
    detail: detailParts.join(' · ') || '本地语料库',
    corpusId,
    openedAt: new Date().toISOString()
  }
}
