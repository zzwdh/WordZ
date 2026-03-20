const numberFormatter = new Intl.NumberFormat('zh-CN')

export function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, function (char) {
    const map = {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}
    return map[char]
  })
}

export function formatCount(value) {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue)) return '0'
  return numberFormatter.format(numericValue)
}

export function yieldToUI() {
  return new Promise(resolve => requestAnimationFrame(() => resolve()))
}

export function clampNumber(value, min, max, fallback) {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue)) return fallback
  return Math.min(Math.max(numericValue, min), max)
}

export function resolvePageSize(value, totalRows, fallback = 10) {
  if (value === 'all') return Math.max(totalRows, 1)
  const parsedValue = Number(value)
  if (!Number.isFinite(parsedValue) || parsedValue <= 0) return fallback
  return parsedValue
}

export function getPreviewText(text, limit) {
  if (text.length <= limit) return text
  return `${text.slice(0, limit)}\n\n[预览已截断，完整语料仍会参与统计、检索和导出]`
}

export function normalizeWindowSizeInput(control, fallbackValue = 5) {
  if (!control) return fallbackValue
  const rawValue = typeof control.value === 'string' ? control.value.trim() : ''
  if (!rawValue) {
    control.value = String(fallbackValue)
    return fallbackValue
  }
  const parsedValue = Number(rawValue)
  if (!Number.isFinite(parsedValue) || parsedValue < 0) {
    control.value = String(fallbackValue)
    return fallbackValue
  }
  const normalizedValue = String(Math.max(0, Math.trunc(parsedValue)))
  control.value = normalizedValue
  return Number(normalizedValue)
}

export function readWindowSizeInput(control, label) {
  const rawValue = typeof control.value === 'string' ? control.value.trim() : ''
  if (!rawValue) throw new Error(`${label}请输入 0 或更大的整数`)
  const parsedValue = Number(rawValue)
  if (!Number.isFinite(parsedValue) || parsedValue < 0 || !Number.isInteger(parsedValue)) {
    throw new Error(`${label}请输入 0 或更大的整数`)
  }
  control.value = String(parsedValue)
  return parsedValue
}

export function setButtonsBusy(buttons, busy) {
  for (const button of buttons) {
    if (button) button.disabled = busy
  }
}

export async function saveTableFile(defaultBaseName, rows, feedback = {}) {
  const showAlert = typeof feedback.showAlert === 'function'
    ? feedback.showAlert
    : async ({ message }) => {
      if (message) console.warn(message)
    }
  const showToast = typeof feedback.showToast === 'function' ? feedback.showToast : () => {}

  if (!rows || rows.length === 0) {
    showToast('没有可导出的内容', { title: '暂无导出数据' })
    return
  }
  if (!window.electronAPI?.saveTableFile) {
    await showAlert({
      title: '导出不可用',
      message: '当前 preload.js 还没有接好 saveTableFile'
    })
    return
  }
  const result = await window.electronAPI.saveTableFile(defaultBaseName, rows)
  if (!result.success) {
    if (result.canceled) {
      showToast('已取消导出保存', { title: '未导出文件' })
      return
    }
    await showAlert({
      title: '导出失败',
      message: result.message || '导出失败'
    })
    return
  }
  showToast(result.filePath ? `已导出到：${result.filePath}` : '导出成功', {
    title: '导出完成',
    type: 'success',
    duration: 4200
  })
}
