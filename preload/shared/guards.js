const SAFE_ID_PATTERN = /^[A-Za-z0-9_-]{1,160}$/
const MAX_EXPORT_ROWS = 250000
const MAX_EXPORT_COLUMNS = 256
const MAX_EXPORT_CELL_LENGTH = 100000

function normalizeTextInput(value, maxLength) {
  return String(value ?? '').trim().slice(0, maxLength)
}

function normalizeIdentifier(value, { allowAll = false, allowEmpty = false } = {}) {
  const normalizedValue = String(value ?? '').trim()
  if (!normalizedValue) return allowEmpty ? '' : ''
  if (allowAll && normalizedValue === 'all') return 'all'
  if (!SAFE_ID_PATTERN.test(normalizedValue)) return ''
  return normalizedValue
}

function normalizeIdentifierList(values, { allowEmpty = false } = {}) {
  if (!Array.isArray(values)) return []
  const seen = new Set()
  const normalizedValues = []

  for (const value of values) {
    const normalizedValue = normalizeIdentifier(value, { allowEmpty })
    if (!normalizedValue || seen.has(normalizedValue)) continue
    seen.add(normalizedValue)
    normalizedValues.push(normalizedValue)
  }

  return normalizedValues
}

function normalizeTableRows(rows) {
  if (!Array.isArray(rows)) return []

  return rows.slice(0, MAX_EXPORT_ROWS).map(row => {
    if (!Array.isArray(row)) return []
    return row
      .slice(0, MAX_EXPORT_COLUMNS)
      .map(cell => String(cell ?? '').slice(0, MAX_EXPORT_CELL_LENGTH))
  })
}

function clampZoomFactor(factor) {
  const numericFactor = Number(factor)
  if (!Number.isFinite(numericFactor)) return 1
  return Math.min(Math.max(numericFactor, 0.8), 1.35)
}

function clampSmokeDelayMs(value) {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue) || numericValue <= 0) return 0
  return Math.min(Math.trunc(numericValue), 10000)
}

function normalizeBoolean(value) {
  if (typeof value === 'boolean') return value
  return ['1', 'true', 'yes', 'on'].includes(String(value ?? '').trim().toLowerCase())
}

function normalizeNotificationAction(action) {
  if (!action) return null
  if (typeof action === 'string') {
    const actionId = normalizeTextInput(action, 80)
    return actionId ? { actionId, actionPayload: null } : null
  }
  if (typeof action !== 'object') return null
  const actionId = normalizeTextInput(action.actionId ?? action.id, 80)
  if (!actionId) return null
  return {
    actionId,
    actionPayload: action.actionPayload ?? action.payload ?? null
  }
}

module.exports = {
  clampSmokeDelayMs,
  clampZoomFactor,
  normalizeBoolean,
  normalizeIdentifier,
  normalizeIdentifierList,
  normalizeNotificationAction,
  normalizeTableRows,
  normalizeTextInput
}
