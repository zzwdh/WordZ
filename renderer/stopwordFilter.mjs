const DEFAULT_STOPWORD_WORDS = Object.freeze([
  'a',
  'an',
  'and',
  'are',
  'as',
  'at',
  'be',
  'been',
  'being',
  'but',
  'by',
  'for',
  'from',
  'had',
  'has',
  'have',
  'he',
  'her',
  'hers',
  'him',
  'his',
  'i',
  'if',
  'in',
  'into',
  'is',
  'it',
  'its',
  'me',
  'my',
  'of',
  'on',
  'or',
  'our',
  'ours',
  'she',
  'that',
  'the',
  'their',
  'theirs',
  'them',
  'they',
  'this',
  'to',
  'us',
  'was',
  'we',
  'were',
  'with',
  'you',
  'your',
  'yours'
])

export const DEFAULT_STOPWORD_LIST_TEXT = `${DEFAULT_STOPWORD_WORDS.join('\n')}\n`

export function normalizeStopwordMode(mode = 'exclude') {
  return String(mode || '').trim().toLowerCase() === 'include' ? 'include' : 'exclude'
}

export function normalizeStopwordListText(text = DEFAULT_STOPWORD_LIST_TEXT) {
  return String(text ?? DEFAULT_STOPWORD_LIST_TEXT)
    .replace(/\r\n?/gu, '\n')
    .trim()
}

export function parseStopwordList(text = DEFAULT_STOPWORD_LIST_TEXT) {
  const normalizedText = normalizeStopwordListText(text)
  if (!normalizedText) return []
  const seen = new Set()
  const words = []
  for (const part of normalizedText.split(/[\n,，;；\t ]+/u)) {
    const entry = String(part || '').trim().toLowerCase()
    if (!entry || seen.has(entry)) continue
    seen.add(entry)
    words.push(entry)
  }
  return words
}

export function normalizeStopwordFilterState(state = {}) {
  const hasExplicitListText = typeof state?.listText === 'string'
  const listTextSource = hasExplicitListText ? state.listText : DEFAULT_STOPWORD_LIST_TEXT
  const listText = parseStopwordList(listTextSource).join('\n')
  return {
    enabled: state?.enabled === true,
    mode: normalizeStopwordMode(state?.mode),
    listText
  }
}

export function buildStopwordFilterKey(state = {}) {
  const normalizedState = normalizeStopwordFilterState(state)
  return `${normalizedState.enabled ? '1' : '0'}|${normalizedState.mode}|${normalizedState.listText}`
}

function tokenizeValue(value = '') {
  const rawValue = String(value || '').trim().toLowerCase()
  if (!rawValue) return []
  const normalized = rawValue.replace(/[^\p{L}\p{N}'-]+/gu, ' ')
  return normalized
    .split(/\s+/u)
    .map(token => token.trim())
    .filter(Boolean)
}

export function createStopwordMatcher(state = {}) {
  const normalizedState = normalizeStopwordFilterState(state)
  const list = parseStopwordList(normalizedState.listText)
  const stopwordSet = new Set(list)
  if (!normalizedState.enabled || stopwordSet.size === 0) {
    return {
      enabled: false,
      mode: normalizedState.mode,
      size: stopwordSet.size,
      stopwordSet,
      matches: () => true,
      contains: () => false
    }
  }

  function contains(text = '') {
    const tokens = tokenizeValue(text)
    if (tokens.length === 0) return false
    return tokens.some(token => stopwordSet.has(token))
  }

  return {
    enabled: true,
    mode: normalizedState.mode,
    size: stopwordSet.size,
    stopwordSet,
    contains,
    matches(text = '') {
      const matched = contains(text)
      return normalizedState.mode === 'include' ? matched : !matched
    }
  }
}

export function getStopwordSummaryText(state = {}) {
  const normalizedState = normalizeStopwordFilterState(state)
  const count = parseStopwordList(normalizedState.listText).length
  if (!normalizedState.enabled) {
    return 'Stopword 关闭'
  }
  if (count === 0) {
    return '词表为空 · 当前不生效'
  }
  return normalizedState.mode === 'include'
    ? `仅保留词表内词项 · ${count} 词`
    : `筛去词表内词项 · ${count} 词`
}
