import { TASK_CENTER_LIMIT } from './constants.mjs'

function formatTaskCenterDuration(durationMs) {
  const normalizedDuration = Math.max(0, Number(durationMs) || 0)
  if (normalizedDuration < 1000) return `${normalizedDuration}ms`
  if (normalizedDuration < 10000) return `${(normalizedDuration / 1000).toFixed(1)}s`
  if (normalizedDuration < 60000) return `${Math.round(normalizedDuration / 1000)}s`
  const minutes = Math.floor(normalizedDuration / 60000)
  const seconds = Math.round((normalizedDuration % 60000) / 1000)
  return `${minutes}m ${seconds}s`
}

function getTaskCenterStatusLabel(status) {
  if (status === 'queued') return '排队中'
  if (status === 'running') return '进行中'
  if (status === 'success') return '已完成'
  if (status === 'cancelled') return '已取消'
  return '失败'
}

export function createTaskCenterController({ dom, setButtonLabel }) {
  const timeFormatter = new Intl.DateTimeFormat('zh-CN', {
    hour: '2-digit',
    minute: '2-digit'
  })

  let isOpen = false
  let entrySequence = 0
  let entries = []
  const activeEntryIds = new Map()
  let metaSuffix = ''

  function updateButtonLabel() {
    if (!dom?.taskCenterButton) return
    const activeCount = entries.filter(entry => entry.status === 'running').length
    setButtonLabel(dom.taskCenterButton, activeCount > 0 ? `任务（${activeCount}）` : '任务')
  }

  function setOpen(open) {
    if (!dom?.taskCenterPanel || !dom?.taskCenterButton) return
    isOpen = Boolean(open)
    dom.taskCenterPanel.classList.toggle('hidden', !isOpen)
    dom.taskCenterButton.setAttribute('aria-expanded', String(isOpen))
  }

  function render() {
    if (!dom?.taskCenterList || !dom?.taskCenterMeta) return

    const activeCount = entries.filter(entry => entry.status === 'running').length
    const queuedCount = entries.filter(entry => entry.status === 'queued').length
    if (activeCount > 0 || queuedCount > 0) {
      const suffix = metaSuffix ? `，${metaSuffix}` : ''
      dom.taskCenterMeta.textContent = `运行中 ${activeCount} 项，排队 ${queuedCount} 项${suffix}，已保留最近 ${entries.length} 条记录。`
    } else if (entries.length > 0) {
      dom.taskCenterMeta.textContent = `最近 ${entries.length} 条分析任务记录。`
    } else {
      dom.taskCenterMeta.textContent = '最近的分析任务会显示在这里。'
    }

    dom.taskCenterList.replaceChildren()
    if (entries.length === 0) {
      const emptyNode = document.createElement('div')
      emptyNode.className = 'task-center-empty'
      emptyNode.textContent = '最近的统计、KWIC 和 Collocate 任务会显示在这里。'
      dom.taskCenterList.append(emptyNode)
      updateButtonLabel()
      return
    }

    for (const entry of entries) {
      const article = document.createElement('article')
      article.className = 'task-center-item'

      const head = document.createElement('div')
      head.className = 'task-center-item-head'

      const title = document.createElement('div')
      title.className = 'task-center-title'
      title.textContent = entry.title

      const status = document.createElement('span')
      status.className = `task-center-status is-${entry.status}`
      status.textContent = getTaskCenterStatusLabel(entry.status)

      head.append(title, status)

      const detail = document.createElement('div')
      detail.className = 'task-center-detail'
      detail.textContent = entry.detail

      const meta = document.createElement('div')
      meta.className = 'task-center-item-meta'
      meta.textContent = entry.status === 'running'
        ? `开始于 ${timeFormatter.format(new Date(entry.startedAt))}`
        : entry.status === 'queued'
          ? `排队于 ${timeFormatter.format(new Date(entry.startedAt))}`
        : `${timeFormatter.format(new Date(entry.finishedAt || entry.startedAt))} · 用时 ${formatTaskCenterDuration(entry.durationMs)}`

      article.append(head, detail, meta)
      dom.taskCenterList.append(article)
    }

    updateButtonLabel()
  }

  function updateEntry(entryId, patch) {
    let hasUpdated = false
    entries = entries.map(entry => {
      if (entry.id !== entryId) return entry
      hasUpdated = true
      return { ...entry, ...patch }
    })
    if (hasUpdated) render()
  }

  return {
    getEntries() {
      return entries.slice()
    },
    isOpen() {
      return isOpen
    },
    render,
    setOpen,
    setMetaSuffix(suffix = '') {
      metaSuffix = String(suffix || '').trim()
      render()
    },
    startEntry(taskKey, title, detail) {
      return this.startEntryWithStatus(taskKey, title, detail, 'running')
    },
    startEntryWithStatus(taskKey, title, detail, status = 'running') {
      const entryId = `task-${++entrySequence}`
      const normalizedStatus = status === 'queued' ? 'queued' : 'running'
      const entry = {
        id: entryId,
        taskKey,
        title,
        detail,
        status: normalizedStatus,
        startedAt: Date.now(),
        finishedAt: null,
        durationMs: 0
      }

      entries = [entry, ...entries].slice(0, TASK_CENTER_LIMIT)
      if (normalizedStatus === 'running') {
        activeEntryIds.set(taskKey, entryId)
      }
      render()
      return entryId
    },
    promoteQueuedEntry(taskKey, detail = '') {
      const entry = entries.find(item => item.taskKey === taskKey && item.status === 'queued')
      if (!entry) return false
      updateEntry(entry.id, {
        status: 'running',
        detail: detail || entry.detail,
        startedAt: Date.now(),
        finishedAt: null,
        durationMs: 0
      })
      activeEntryIds.set(taskKey, entry.id)
      return true
    },
    updateActiveEntry(taskKey, patch) {
      const entryId = activeEntryIds.get(taskKey)
      if (!entryId) return
      updateEntry(entryId, patch)
    },
    finishEntry(taskKey, status, detail) {
      const entryId = activeEntryIds.get(taskKey)
      if (!entryId) return

      const entry = entries.find(item => item.id === entryId)
      if (!entry) {
        activeEntryIds.delete(taskKey)
        return
      }

      updateEntry(entryId, {
        status,
        detail,
        finishedAt: Date.now(),
        durationMs: Date.now() - entry.startedAt
      })
      activeEntryIds.delete(taskKey)
    },
    cancelQueuedEntries(detail = '已取消排队任务') {
      const finishedAt = Date.now()
      let cancelledCount = 0
      entries = entries.map(entry => {
        if (entry.status !== 'queued') return entry
        cancelledCount += 1
        return {
          ...entry,
          status: 'cancelled',
          detail,
          finishedAt,
          durationMs: Math.max(0, finishedAt - entry.startedAt)
        }
      })
      if (cancelledCount > 0) render()
      return cancelledCount
    }
  }
}
