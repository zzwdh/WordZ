export function createTableRenderer({ formatCount, largeTableThreshold, chunkSize }) {
  let tableRenderJobSeq = 0
  const tableRenderJobs = new WeakMap()
  const tableRenderCleanups = new WeakMap()
  const MIN_CHUNK_SIZE = Math.max(24, Math.floor(chunkSize * 0.25))
  const MAX_CHUNK_SIZE = Math.max(chunkSize, chunkSize * 4)
  const TARGET_CHUNK_MS = 8
  const STATUS_UPDATE_STEP = Math.max(chunkSize, 160)
  const VIRTUAL_TABLE_THRESHOLD = Math.max(largeTableThreshold * 6, 1800)

  function scheduleChunk(fn) {
    if (typeof window !== 'undefined' && typeof window.requestIdleCallback === 'function') {
      window.requestIdleCallback(() => requestAnimationFrame(fn), { timeout: 32 })
      return
    }
    requestAnimationFrame(fn)
  }

  function clearTableRenderCleanup(container) {
    const cleanup = tableRenderCleanups.get(container)
    if (typeof cleanup === 'function') {
      try {
        cleanup()
      } catch {
        // ignore cleanup failures
      }
    }
    tableRenderCleanups.delete(container)
  }

  function setTableRenderCleanup(container, cleanup) {
    clearTableRenderCleanup(container)
    if (typeof cleanup === 'function') {
      tableRenderCleanups.set(container, cleanup)
    }
  }

  function cancelTableRender(container) {
    if (!container) return
    clearTableRenderCleanup(container)
    tableRenderJobs.set(container, ++tableRenderJobSeq)
  }

  function isTableRenderActive(container, jobId) {
    return tableRenderJobs.get(container) === jobId
  }

  function renderTableInChunks({
    container,
    rows,
    tableClassName = '',
    headerHtml,
    renderRow,
    emptyHtml,
    rowUnit = '行',
    onChunkRendered,
    virtualize = true
  }) {
    cancelTableRender(container)
    setTableRenderCleanup(container, null)

    if (!rows || rows.length === 0) {
      container.innerHTML = emptyHtml
      return
    }

    const tableClass = tableClassName ? `data-table ${tableClassName}` : 'data-table'
    if (rows.length <= largeTableThreshold) {
      const rowsHtml = rows.map((row, index) => renderRow(row, index)).join('')
      container.innerHTML = `<table class="${tableClass}"><thead>${headerHtml}</thead><tbody>${rowsHtml}</tbody></table>`
      if (typeof onChunkRendered === 'function') {
        onChunkRendered({ start: 0, end: rows.length, total: rows.length })
      }
      return
    }

    if (virtualize && rows.length >= VIRTUAL_TABLE_THRESHOLD) {
      const jobId = ++tableRenderJobSeq
      tableRenderJobs.set(container, jobId)

      const columnCount = Math.max((headerHtml.match(/<th\b/gi) || []).length, 1)
      const overscanRows = 12
      const maxRowCacheSize = 1200
      const rowHtmlCache = new Map()
      let rowHeight = 42
      let lastStart = -1
      let lastEnd = -1
      let rafId = 0
      let needsRender = false

      container.innerHTML = `
        <div class="table-render-status">正在初始化虚拟渲染...</div>
        <table class="${tableClass}">
          <thead>${headerHtml}</thead>
          <tbody></tbody>
        </table>
      `

      const statusNode = container.querySelector('.table-render-status')
      const tbody = container.querySelector('tbody')
      if (!tbody) return

      const wrapVirtualRow = rowHtml => rowHtml.replace(/<tr(\s|>)/i, '<tr data-virtual-row="1"$1')
      const getVirtualRowHtml = index => {
        if (rowHtmlCache.has(index)) {
          return rowHtmlCache.get(index)
        }
        const rowHtml = wrapVirtualRow(renderRow(rows[index], index))
        rowHtmlCache.set(index, rowHtml)
        if (rowHtmlCache.size > maxRowCacheSize) {
          const oldestKey = rowHtmlCache.keys().next().value
          rowHtmlCache.delete(oldestKey)
        }
        return rowHtml
      }
      const updateStatus = (start, end) => {
        if (!statusNode) return
        statusNode.textContent = `虚拟渲染 ${formatCount(start + 1)} - ${formatCount(end)} / ${formatCount(rows.length)} ${rowUnit}`
      }

      const renderVisibleRows = () => {
        if (!isTableRenderActive(container, jobId)) return
        const viewportHeight = Math.max(container.clientHeight || 420, 180)
        const visibleCount = Math.max(Math.ceil(viewportHeight / rowHeight), 1)
        const start = Math.max(Math.floor(container.scrollTop / rowHeight) - overscanRows, 0)
        const end = Math.min(start + visibleCount + overscanRows * 2, rows.length)

        if (start === lastStart && end === lastEnd) return
        lastStart = start
        lastEnd = end

        const topHeight = Math.max(Math.round(start * rowHeight), 0)
        const bottomHeight = Math.max(Math.round((rows.length - end) * rowHeight), 0)
        let rowsHtml = ''
        if (topHeight > 0) {
          rowsHtml += `<tr class="virtual-spacer-row" aria-hidden="true"><td colspan="${columnCount}" style="height:${topHeight}px"></td></tr>`
        }
        for (let index = start; index < end; index += 1) {
          rowsHtml += getVirtualRowHtml(index)
        }
        if (bottomHeight > 0) {
          rowsHtml += `<tr class="virtual-spacer-row" aria-hidden="true"><td colspan="${columnCount}" style="height:${bottomHeight}px"></td></tr>`
        }

        tbody.innerHTML = rowsHtml

        const firstRealRow = tbody.querySelector('tr[data-virtual-row="1"]')
        if (firstRealRow) {
          const measuredHeight = firstRealRow.getBoundingClientRect().height
          if (Number.isFinite(measuredHeight) && measuredHeight >= 18) {
            rowHeight = rowHeight * 0.75 + measuredHeight * 0.25
          }
        }

        updateStatus(start, end)
        if (typeof onChunkRendered === 'function') {
          onChunkRendered({ start, end, total: rows.length, virtualized: true })
        }
      }

      const scheduleVisibleRender = () => {
        if (needsRender) return
        needsRender = true
        rafId = requestAnimationFrame(() => {
          needsRender = false
          renderVisibleRows()
        })
      }

      const handleScroll = () => {
        if (!isTableRenderActive(container, jobId)) return
        scheduleVisibleRender()
      }

      const handleResize = () => {
        if (!isTableRenderActive(container, jobId)) return
        scheduleVisibleRender()
      }

      container.addEventListener('scroll', handleScroll, { passive: true })
      window.addEventListener('resize', handleResize)
      setTableRenderCleanup(container, () => {
        container.removeEventListener('scroll', handleScroll)
        window.removeEventListener('resize', handleResize)
        if (rafId) {
          cancelAnimationFrame(rafId)
        }
      })

      scheduleChunk(renderVisibleRows)
      return
    }

    const jobId = ++tableRenderJobSeq
    tableRenderJobs.set(container, jobId)
    container.innerHTML = `
      <div class="table-render-status">正在渲染 0 / ${formatCount(rows.length)} ${rowUnit}</div>
      <table class="${tableClass}">
        <thead>${headerHtml}</thead>
        <tbody></tbody>
      </table>
    `

    const statusNode = container.querySelector('.table-render-status')
    const tbody = container.querySelector('tbody')
    let index = 0
    let dynamicChunkSize = chunkSize
    let lastStatusEnd = 0

    const updateStatus = end => {
      if (!statusNode) return
      statusNode.textContent =
        end < rows.length
          ? `正在渲染 ${formatCount(end)} / ${formatCount(rows.length)} ${rowUnit}`
          : `已渲染 ${formatCount(rows.length)} ${rowUnit}`
    }

    const appendChunk = () => {
      if (!isTableRenderActive(container, jobId)) return
      if (!tbody) return

      const start = index
      const end = Math.min(index + dynamicChunkSize, rows.length)
      const chunkStartTs = performance.now()
      const renderedRows = new Array(end - start)
      let renderedCount = 0
      for (; index < end; index++) {
        renderedRows[renderedCount++] = renderRow(rows[index], index)
      }
      tbody.insertAdjacentHTML('beforeend', renderedRows.join(''))

      if (typeof onChunkRendered === 'function') {
        onChunkRendered({ start, end, total: rows.length })
      }

      const chunkElapsedMs = performance.now() - chunkStartTs
      if (chunkElapsedMs > TARGET_CHUNK_MS && dynamicChunkSize > MIN_CHUNK_SIZE) {
        dynamicChunkSize = Math.max(MIN_CHUNK_SIZE, Math.floor(dynamicChunkSize * 0.7))
      } else if (chunkElapsedMs < TARGET_CHUNK_MS * 0.5 && dynamicChunkSize < MAX_CHUNK_SIZE) {
        dynamicChunkSize = Math.min(MAX_CHUNK_SIZE, Math.ceil(dynamicChunkSize * 1.25))
      }

      if (end - lastStatusEnd >= STATUS_UPDATE_STEP || end >= rows.length) {
        updateStatus(end)
        lastStatusEnd = end
      }

      if (end < rows.length) {
        scheduleChunk(appendChunk)
      }
    }

    scheduleChunk(appendChunk)
  }

  return {
    cancelTableRender,
    renderTableInChunks
  }
}
