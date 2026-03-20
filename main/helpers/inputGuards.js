const path = require('path')

const SAFE_ID_PATTERN = /^[A-Za-z0-9_-]{1,160}$/
const MAX_EXPORT_ROWS = 250000
const MAX_EXPORT_COLUMNS = 256
const MAX_EXPORT_CELL_LENGTH = 100000

function normalizeTextInput(value, { fallback = '', maxLength = 160 } = {}) {
  return String(value ?? fallback).trim().slice(0, maxLength)
}

function normalizeFilePathInput(value, { fieldName = '文件路径' } = {}) {
  const normalizedValue = String(value ?? '').trim()
  if (!normalizedValue) {
    throw new Error(`${fieldName}不能为空`)
  }
  if (normalizedValue.includes('\0')) {
    throw new Error(`${fieldName}格式不合法`)
  }
  return path.resolve(normalizedValue)
}

function normalizeBooleanInput(value) {
  if (typeof value === 'boolean') return value
  const normalizedValue = String(value ?? '').trim().toLowerCase()
  return ['1', 'true', 'yes', 'on'].includes(normalizedValue)
}

function normalizeExternalUrlInput(value) {
  const normalizedValue = String(value ?? '').trim()
  if (!normalizedValue) {
    throw new Error('链接不能为空')
  }

  let parsedUrl
  try {
    parsedUrl = new URL(normalizedValue)
  } catch {
    throw new Error('链接格式不合法')
  }

  if (!['https:', 'http:'].includes(parsedUrl.protocol)) {
    throw new Error('仅支持打开 http 或 https 链接')
  }

  return parsedUrl.toString()
}

function normalizeIdentifier(value, { fieldName = '标识', allowAll = false, allowEmpty = false } = {}) {
  const normalizedValue = String(value ?? '').trim()
  if (!normalizedValue) {
    if (allowEmpty) return ''
    throw new Error(`${fieldName}不能为空`)
  }
  if (allowAll && normalizedValue === 'all') return 'all'
  if (!SAFE_ID_PATTERN.test(normalizedValue)) {
    throw new Error(`${fieldName}格式不合法`)
  }
  return normalizedValue
}

function normalizeTableRows(rows) {
  if (!Array.isArray(rows)) {
    throw new Error('表格数据格式不合法')
  }
  if (rows.length > MAX_EXPORT_ROWS) {
    throw new Error('导出数据过大，请缩小导出范围后重试')
  }

  return rows.map((row, rowIndex) => {
    if (!Array.isArray(row)) {
      throw new Error(`第 ${rowIndex + 1} 行表格数据格式不合法`)
    }
    if (row.length > MAX_EXPORT_COLUMNS) {
      throw new Error(`第 ${rowIndex + 1} 行列数过多，请缩小导出范围后重试`)
    }

    return row.map(cell => String(cell ?? '').slice(0, MAX_EXPORT_CELL_LENGTH))
  })
}

module.exports = {
  normalizeBooleanInput,
  normalizeExternalUrlInput,
  normalizeFilePathInput,
  normalizeIdentifier,
  normalizeTableRows,
  normalizeTextInput
}
