export function createTableRenderer({ formatCount, largeTableThreshold, chunkSize }) {
  let tableRenderJobSeq = 0
  const tableRenderJobs = new WeakMap()

  function cancelTableRender(container) {
    if (!container) return
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
    onChunkRendered
  }) {
    cancelTableRender(container)

    if (!rows || rows.length === 0) {
      container.innerHTML = emptyHtml
      return
    }

    const tableClass = tableClassName ? `data-table ${tableClassName}` : 'data-table'
    if (rows.length <= largeTableThreshold) {
      const rowsHtml = rows.map((row, index) => renderRow(row, index)).join('')
      container.innerHTML = `<table class="${tableClass}"><thead>${headerHtml}</thead><tbody>${rowsHtml}</tbody></table>`
      if (typeof onChunkRendered === 'function') {
        onChunkRendered({ start: 0, end: rows.length, rows })
      }
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

    const appendChunk = () => {
      if (!isTableRenderActive(container, jobId)) return

      const start = index
      const end = Math.min(index + chunkSize, rows.length)
      let rowsHtml = ''
      for (; index < end; index++) {
        rowsHtml += renderRow(rows[index], index)
      }
      tbody.insertAdjacentHTML('beforeend', rowsHtml)

      if (typeof onChunkRendered === 'function') {
        onChunkRendered({ start, end, rows })
      }

      if (statusNode) {
        statusNode.textContent =
          end < rows.length
            ? `正在渲染 ${formatCount(end)} / ${formatCount(rows.length)} ${rowUnit}`
            : `已渲染 ${formatCount(rows.length)} ${rowUnit}`
      }

      if (end < rows.length) {
        requestAnimationFrame(appendChunk)
      }
    }

    requestAnimationFrame(appendChunk)
  }

  return {
    cancelTableRender,
    renderTableInChunks
  }
}
