export function splitTextIntoSentences(text) {
  const normalized = String(text || '').replace(/\r\n/g, '\n').trim()
  if (!normalized) return []
  const lines = normalized.split(/\n+/).map(line => line.trim()).filter(Boolean)
  const sentences = []
  for (const line of lines) {
    const matches = line.match(/[^.!?。！？]+[.!?。！？]?/g)
    if (matches && matches.length > 0) {
      for (const item of matches) {
        const sentence = item.trim()
        if (sentence) sentences.push(sentence)
      }
    } else if (line) {
      sentences.push(line)
    }
  }
  return sentences
}

export function parseSentenceParts(sentenceText) {
  const matches = sentenceText.match(/[\p{L}\p{N}']+|[^\p{L}\p{N}']+/gu) || []
  let wordIndex = 0
  const parts = []
  const normalizedTokens = []
  const rawTokens = []
  for (const partText of matches) {
    const isWord = /^[\p{L}\p{N}']+$/u.test(partText)
    if (isWord) {
      const normalizedToken = partText.toLowerCase()
      parts.push({ text: partText, isWord: true, rawToken: partText, norm: normalizedToken, wordIndex })
      normalizedTokens.push(normalizedToken)
      rawTokens.push(partText)
      wordIndex += 1
    } else {
      parts.push({ text: partText, isWord: false })
    }
  }
  return { parts, normalizedTokens, rawTokens }
}

const CORPUS_DATA_CACHE_LIMIT = 8
const CORPUS_QUERY_CACHE_LIMIT = 96
const corpusDataCache = new Map()
const tokenFrequencyCache = new WeakMap()
const tokenObjectIndexCache = new WeakMap()
const kwicQueryCache = new WeakMap()
const collocateQueryCache = new WeakMap()
const collocateGlobalFreqCache = new WeakMap()

function hashText(value) {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }
  return (hash >>> 0).toString(16)
}

function buildCorpusCacheKey(text) {
  return `${text.length}:${hashText(text)}`
}

function cloneCorpusData(cached) {
  return {
    sentences: cached.sentences.slice(),
    tokenObjects: cached.tokenObjects.slice(),
    tokens: cached.tokens.slice()
  }
}

function getCachedCorpusData(text) {
  const cacheKey = buildCorpusCacheKey(text)
  const cachedEntry = corpusDataCache.get(cacheKey)
  if (!cachedEntry || cachedEntry.text !== text) return null
  corpusDataCache.delete(cacheKey)
  corpusDataCache.set(cacheKey, cachedEntry)
  return cloneCorpusData(cachedEntry.data)
}

function setCachedCorpusData(text, data) {
  const cacheKey = buildCorpusCacheKey(text)
  corpusDataCache.set(cacheKey, {
    text,
    data: cloneCorpusData(data)
  })
  while (corpusDataCache.size > CORPUS_DATA_CACHE_LIMIT) {
    const oldestKey = corpusDataCache.keys().next().value
    if (oldestKey === undefined) break
    corpusDataCache.delete(oldestKey)
  }
}

function getOrCreateScopedQueryCache(cacheStore, cacheKey) {
  let scopedCache = cacheStore.get(cacheKey)
  if (!scopedCache) {
    scopedCache = new Map()
    cacheStore.set(cacheKey, scopedCache)
  }
  return scopedCache
}

function getCachedScopedQueryResult(scopedCache, key) {
  if (!scopedCache.has(key)) return null
  const cachedValue = scopedCache.get(key)
  scopedCache.delete(key)
  scopedCache.set(key, cachedValue)
  return cachedValue
}

function setScopedQueryResult(scopedCache, key, value) {
  scopedCache.set(key, value)
  while (scopedCache.size > CORPUS_QUERY_CACHE_LIMIT) {
    const oldestKey = scopedCache.keys().next().value
    if (oldestKey === undefined) break
    scopedCache.delete(oldestKey)
  }
}

function serializeSearchOptions(options = {}) {
  const normalized = normalizeSearchOptions(options)
  return `${normalized.words ? '1' : '0'}${normalized.caseSensitive ? '1' : '0'}${normalized.regex ? '1' : '0'}`
}

function buildTokenObjectIndexes(tokenObjects) {
  const rawTokenIndexMap = new Map()
  const tokenIndexMap = new Map()
  for (let index = 0; index < tokenObjects.length; index += 1) {
    const tokenObject = tokenObjects[index]
    const rawToken = String(tokenObject?.rawToken || tokenObject?.token || '')
    const normalizedToken = String(tokenObject?.token || tokenObject?.rawToken || '').toLowerCase()

    if (rawToken) {
      const rawBucket = rawTokenIndexMap.get(rawToken) || []
      rawBucket.push(index)
      rawTokenIndexMap.set(rawToken, rawBucket)
    }

    if (normalizedToken) {
      const normalizedBucket = tokenIndexMap.get(normalizedToken) || []
      normalizedBucket.push(index)
      tokenIndexMap.set(normalizedToken, normalizedBucket)
    }
  }
  return {
    rawTokenIndexMap,
    tokenIndexMap
  }
}

function getTokenObjectIndexes(tokenObjects) {
  const source = Array.isArray(tokenObjects) ? tokenObjects : []
  let indexes = tokenObjectIndexCache.get(source)
  if (!indexes) {
    indexes = buildTokenObjectIndexes(source)
    tokenObjectIndexCache.set(source, indexes)
  }
  return indexes
}

function getCollocateGlobalFrequencyMap(tokenObjects, caseSensitive) {
  const source = Array.isArray(tokenObjects) ? tokenObjects : []
  let cacheBucket = collocateGlobalFreqCache.get(source)
  if (!cacheBucket) {
    cacheBucket = {
      caseSensitive: null,
      caseInsensitive: null
    }
    collocateGlobalFreqCache.set(source, cacheBucket)
  }

  const cacheKey = caseSensitive ? 'caseSensitive' : 'caseInsensitive'
  if (cacheBucket[cacheKey]) return cacheBucket[cacheKey]

  const freqMap = {}
  for (const item of source) {
    const tokenKey = caseSensitive
      ? String(item?.rawToken || item?.token || '')
      : String(item?.token || item?.rawToken || '').toLowerCase()
    if (!tokenKey) continue
    if (!freqMap[tokenKey]) freqMap[tokenKey] = 0
    freqMap[tokenKey] += 1
  }

  cacheBucket[cacheKey] = freqMap
  return freqMap
}

export function buildCorpusData(text) {
  const normalizedText = String(text || '')
  const cachedCorpusData = getCachedCorpusData(normalizedText)
  if (cachedCorpusData) return cachedCorpusData

  const sentenceTexts = splitTextIntoSentences(normalizedText)
  const sentences = []
  const tokenObjects = []
  const tokens = []
  for (let sentenceId = 0; sentenceId < sentenceTexts.length; sentenceId += 1) {
    const sentenceText = sentenceTexts[sentenceId]
    const parsed = parseSentenceParts(sentenceText)
    const sentence = {
      id: sentenceId,
      text: sentenceText,
      parts: parsed.parts,
      normalizedTokens: parsed.normalizedTokens
    }
    sentences.push(sentence)
    for (let tokenIndex = 0; tokenIndex < parsed.normalizedTokens.length; tokenIndex += 1) {
      const token = parsed.normalizedTokens[tokenIndex]
      const rawToken = parsed.rawTokens[tokenIndex] || token
      tokenObjects.push({ token, rawToken, sentenceId, sentenceTokenIndex: tokenIndex })
      tokens.push(token)
    }
  }

  const corpusData = { sentences, tokenObjects, tokens }
  setCachedCorpusData(normalizedText, corpusData)
  return corpusData
}

export function normalizeSearchOptions(options = {}) {
  return {
    words: options.words !== false,
    caseSensitive: Boolean(options.caseSensitive || options.case),
    regex: Boolean(options.regex)
  }
}

export function buildTokenMatcher(query, options = {}) {
  const normalizedOptions = normalizeSearchOptions(options)
  const normalizedQuery = String(query || '').trim()

  if (!normalizedQuery) {
    return {
      matcher: () => true,
      normalizedQuery,
      options: normalizedOptions,
      error: ''
    }
  }

  if (normalizedOptions.regex) {
    const pattern = normalizedOptions.words ? `^(?:${normalizedQuery})$` : normalizedQuery
    try {
      const regex = new RegExp(pattern, normalizedOptions.caseSensitive ? 'u' : 'iu')
      return {
        matcher: value => regex.test(String(value || '')),
        normalizedQuery,
        options: normalizedOptions,
        error: ''
      }
    } catch (error) {
      return {
        matcher: () => false,
        normalizedQuery,
        options: normalizedOptions,
        error: error && error.message ? `无效的正则表达式：${error.message}` : '无效的正则表达式'
      }
    }
  }

  const normalizedNeedle = normalizedOptions.caseSensitive ? normalizedQuery : normalizedQuery.toLowerCase()
  return {
    matcher: value => {
      const candidate = String(value || '')
      const haystack = normalizedOptions.caseSensitive ? candidate : candidate.toLowerCase()
      return normalizedOptions.words ? haystack === normalizedNeedle : haystack.includes(normalizedNeedle)
    },
    normalizedQuery,
    options: normalizedOptions,
    error: ''
  }
}

export function countWordFrequency(tokens) {
  const sourceTokens = Array.isArray(tokens) ? tokens : []
  const cachedResult = tokenFrequencyCache.get(sourceTokens)
  if (cachedResult) return cachedResult

  const freqMap = {}
  for (const token of sourceTokens) {
    if (!freqMap[token]) freqMap[token] = 0
    freqMap[token] += 1
  }
  tokenFrequencyCache.set(sourceTokens, freqMap)
  return freqMap
}

export function calculateTTR(tokens) {
  if (tokens.length === 0) return 0
  return new Set(tokens).size / tokens.length
}

export function calculateSTTR(tokens, chunkSize = 1000) {
  if (tokens.length === 0) return 0
  if (tokens.length < chunkSize) return calculateTTR(tokens)
  const chunkTTRs = []
  for (let i = 0; i + chunkSize <= tokens.length; i += chunkSize) {
    chunkTTRs.push(calculateTTR(tokens.slice(i, i + chunkSize)))
  }
  if (chunkTTRs.length === 0) return 0
  return chunkTTRs.reduce((sum, value) => sum + value, 0) / chunkTTRs.length
}

export function getSortedFrequencyRows(freqMap) {
  return Object.entries(freqMap).sort((a, b) => {
    if (b[1] !== a[1]) return b[1] - a[1]
    return a[0].localeCompare(b[0])
  })
}

function normalizeNgramSize(rawN) {
  const n = Number(rawN)
  if (!Number.isFinite(n) || !Number.isInteger(n)) {
    throw new Error('Ngram 的 N 必须是正整数')
  }
  if (n <= 0) {
    throw new Error('Ngram 的 N 必须大于 0')
  }
  return n
}

const TOKEN_REGEX = /[\p{L}\p{N}']+/gu
const TOKEN_TRAILING_REGEX = /[\p{L}\p{N}']+$/u

function resolveChunkCharSize(rawChunkCharSize) {
  const chunkSize = Number(rawChunkCharSize)
  if (!Number.isFinite(chunkSize) || !Number.isInteger(chunkSize)) return 200000
  return Math.min(1200000, Math.max(20000, chunkSize))
}

function forEachTokenByChunk(text, { chunkCharSize = 200000, onToken } = {}) {
  const callback = typeof onToken === 'function' ? onToken : () => {}
  const normalizedText = String(text || '').replace(/\r\n/g, '\n')
  if (!normalizedText) return 0

  const safeChunkSize = resolveChunkCharSize(chunkCharSize)
  let offset = 0
  let carry = ''
  let tokenCount = 0

  while (offset < normalizedText.length) {
    const chunkText = normalizedText.slice(offset, offset + safeChunkSize)
    offset += safeChunkSize
    let processText = carry + chunkText
    carry = ''

    if (offset < normalizedText.length) {
      const trailingMatch = processText.match(TOKEN_TRAILING_REGEX)
      if (trailingMatch?.[0] && trailingMatch.index !== undefined) {
        const trailingToken = trailingMatch[0]
        const trailingStart = trailingMatch.index
        if (trailingStart + trailingToken.length === processText.length) {
          carry = trailingToken
          processText = processText.slice(0, trailingStart)
        }
      }
    }

    const tokens = processText.match(TOKEN_REGEX) || []
    for (const token of tokens) {
      const normalizedToken = String(token || '').toLowerCase()
      if (!normalizedToken) continue
      tokenCount += 1
      callback(normalizedToken)
    }
  }

  if (carry) {
    const trailingTokens = carry.match(TOKEN_REGEX) || []
    for (const token of trailingTokens) {
      const normalizedToken = String(token || '').toLowerCase()
      if (!normalizedToken) continue
      tokenCount += 1
      callback(normalizedToken)
    }
  }

  return tokenCount
}

export function computeSegmentedStats(text, { chunkCharSize = 200000, sttrChunkSize = 1000 } = {}) {
  const normalizedSttrChunkSize =
    Number.isFinite(Number(sttrChunkSize)) && Number(sttrChunkSize) > 0
      ? Math.floor(Number(sttrChunkSize))
      : 1000

  const freqMap = {}
  let tokenCount = 0
  let sttrChunkTokenCount = 0
  let sttrChunkCount = 0
  let sttrChunkTTRSum = 0
  let sttrChunkTokenSet = new Set()

  forEachTokenByChunk(text, {
    chunkCharSize,
    onToken: token => {
      if (!freqMap[token]) freqMap[token] = 0
      freqMap[token] += 1
      tokenCount += 1

      sttrChunkTokenSet.add(token)
      sttrChunkTokenCount += 1
      if (sttrChunkTokenCount >= normalizedSttrChunkSize) {
        sttrChunkTTRSum += sttrChunkTokenSet.size / normalizedSttrChunkSize
        sttrChunkCount += 1
        sttrChunkTokenCount = 0
        sttrChunkTokenSet = new Set()
      }
    }
  })

  const typeCount = Object.keys(freqMap).length
  const ttr = tokenCount > 0 ? typeCount / tokenCount : 0
  const sttr =
    tokenCount === 0
      ? 0
      : tokenCount < normalizedSttrChunkSize
        ? ttr
        : sttrChunkCount > 0
          ? sttrChunkTTRSum / sttrChunkCount
          : 0

  return {
    freqRows: getSortedFrequencyRows(freqMap),
    tokenCount,
    typeCount,
    ttr,
    sttr
  }
}

export function computeSegmentedNgramRows(text, rawN = 2, { chunkCharSize = 200000 } = {}) {
  const n = normalizeNgramSize(rawN)
  const freqMap = {}
  const rollingTokens = []

  forEachTokenByChunk(text, {
    chunkCharSize,
    onToken: token => {
      rollingTokens.push(token)
      if (rollingTokens.length < n) return
      if (rollingTokens.length > n) rollingTokens.shift()
      const key = rollingTokens.join(' ')
      if (!key) return
      if (!freqMap[key]) freqMap[key] = 0
      freqMap[key] += 1
    }
  })

  return {
    n,
    rows: getSortedNgramRows(freqMap)
  }
}

export function countNgramFrequency(tokens, rawN = 2) {
  const sourceTokens = Array.isArray(tokens) ? tokens : []
  const n = normalizeNgramSize(rawN)
  const freqMap = {}
  if (sourceTokens.length < n) return freqMap

  for (let index = 0; index <= sourceTokens.length - n; index += 1) {
    const key = sourceTokens.slice(index, index + n).join(' ')
    if (!key) continue
    if (!freqMap[key]) freqMap[key] = 0
    freqMap[key] += 1
  }
  return freqMap
}

export function getSortedNgramRows(freqMap) {
  return Object.entries(freqMap).sort((left, right) => {
    if (right[1] !== left[1]) return right[1] - left[1]
    return left[0].localeCompare(right[0], 'en', { sensitivity: 'base', numeric: true })
  })
}

export function compareCorpusFrequencies(corpusEntries = []) {
  const corpusSummaries = []

  for (let index = 0; index < (Array.isArray(corpusEntries) ? corpusEntries : []).length; index += 1) {
    const entry = corpusEntries[index]
    const content = String(entry?.content || '').trim()
    if (!content) continue

    const corpusId = String(entry?.corpusId || entry?.id || `corpus-${index + 1}`).trim() || `corpus-${index + 1}`
    const corpusName = String(entry?.corpusName || entry?.name || `语料 ${index + 1}`).trim() || `语料 ${index + 1}`
    const folderId = String(entry?.folderId || '').trim()
    const folderName = String(entry?.folderName || '').trim()
    const sourceType = String(entry?.sourceType || 'txt').trim() || 'txt'
    const corpusData = buildCorpusData(content)
    const freqMap = countWordFrequency(corpusData.tokens)
    let topWord = ''
    let topWordCount = 0
    for (const [word, count] of Object.entries(freqMap)) {
      if (
        count > topWordCount ||
        (count === topWordCount && (topWord === '' || word.localeCompare(topWord) < 0))
      ) {
        topWord = word
        topWordCount = count
      }
    }

    corpusSummaries.push({
      corpusId,
      corpusName,
      folderId,
      folderName,
      sourceType,
      tokenCount: corpusData.tokens.length,
      typeCount: Object.keys(freqMap).length,
      ttr: calculateTTR(corpusData.tokens),
      sttr: calculateSTTR(corpusData.tokens, 1000),
      topWord,
      topWordCount,
      freqMap
    })
  }

  const wordMap = new Map()

  for (const summary of corpusSummaries) {
    for (const [word, count] of Object.entries(summary.freqMap)) {
      const existingRow = wordMap.get(word) || {
        word,
        total: 0,
        spread: 0,
        perCorpusMap: new Map()
      }

      existingRow.total += count
      existingRow.spread += 1
      existingRow.perCorpusMap.set(summary.corpusId, {
        corpusId: summary.corpusId,
        corpusName: summary.corpusName,
        folderName: summary.folderName,
        count,
        normFreq: summary.tokenCount > 0 ? (count / summary.tokenCount) * 10000 : 0
      })
      wordMap.set(word, existingRow)
    }
  }

  const rows = []

  for (const entry of wordMap.values()) {
    const perCorpus = []
    let dominantCorpus = null
    let maxNormFreq = -1
    let minNormFreq = Number.POSITIVE_INFINITY
    let maxCount = 0
    let minCount = Number.POSITIVE_INFINITY

    for (const summary of corpusSummaries) {
      const currentValue = entry.perCorpusMap.get(summary.corpusId) || {
        corpusId: summary.corpusId,
        corpusName: summary.corpusName,
        folderName: summary.folderName,
        count: 0,
        normFreq: 0
      }

      perCorpus.push(currentValue)

      if (
        !dominantCorpus ||
        currentValue.normFreq > maxNormFreq ||
        (currentValue.normFreq === maxNormFreq && currentValue.count > (dominantCorpus?.count || 0)) ||
        (
          currentValue.normFreq === maxNormFreq &&
          currentValue.count === (dominantCorpus?.count || 0) &&
          currentValue.corpusName.localeCompare(dominantCorpus?.corpusName || '', 'zh-CN') < 0
        )
      ) {
        dominantCorpus = currentValue
      }

      maxNormFreq = Math.max(maxNormFreq, currentValue.normFreq)
      minNormFreq = Math.min(minNormFreq, currentValue.normFreq)
      maxCount = Math.max(maxCount, currentValue.count)
      minCount = Math.min(minCount, currentValue.count)
    }

    rows.push({
      word: entry.word,
      total: entry.total,
      spread: entry.spread,
      spreadRatio: corpusSummaries.length > 0 ? entry.spread / corpusSummaries.length : 0,
      dominantCorpusId: dominantCorpus?.corpusId || '',
      dominantCorpusName: dominantCorpus?.corpusName || '',
      dominantCount: dominantCorpus?.count || 0,
      dominantNormFreq: dominantCorpus?.normFreq || 0,
      range: Math.max(0, maxNormFreq - minNormFreq),
      maxCount,
      minCount: Number.isFinite(minCount) ? minCount : 0,
      perCorpus
    })
  }

  rows.sort((left, right) => {
    if (right.spread !== left.spread) return right.spread - left.spread
    if (right.total !== left.total) return right.total - left.total
    if (right.range !== left.range) return right.range - left.range
    return left.word.localeCompare(right.word, 'en', { sensitivity: 'base', numeric: true })
  })

  return {
    corpora: corpusSummaries.map(({ freqMap, ...summary }) => summary),
    rows
  }
}

function validateContingencyCount(value, label) {
  if (!Number.isFinite(value) || value < 0 || !Number.isInteger(value)) {
    throw new Error(`${label} 必须是大于等于 0 的整数`)
  }
}

function approximateErf(value) {
  const sign = value < 0 ? -1 : 1
  const x = Math.abs(value)
  const t = 1 / (1 + 0.3275911 * x)
  const y = 1 - (
    (
      (
        (
          (1.061405429 * t) - 1.453152027
        ) * t + 1.421413741
      ) * t - 0.284496736
    ) * t + 0.254829592
  ) * t * Math.exp(-x * x)

  return sign * y
}

function complementaryErrorFunction(value) {
  const erfcValue = 1 - approximateErf(value)
  if (erfcValue < 0) return 0
  if (erfcValue > 2) return 2
  return erfcValue
}

export function calculateChiSquare2x2({ a = 0, b = 0, c = 0, d = 0, yates = false } = {}) {
  const observedA = Number(a)
  const observedB = Number(b)
  const observedC = Number(c)
  const observedD = Number(d)

  validateContingencyCount(observedA, 'A（语料1目标词）')
  validateContingencyCount(observedB, 'B（语料1非目标词）')
  validateContingencyCount(observedC, 'C（语料2目标词）')
  validateContingencyCount(observedD, 'D（语料2非目标词）')

  const rowTotals = [observedA + observedB, observedC + observedD]
  const colTotals = [observedA + observedC, observedB + observedD]
  const total = rowTotals[0] + rowTotals[1]

  if (total === 0) {
    throw new Error('四个频数之和不能为 0')
  }

  if (rowTotals[0] === 0 || rowTotals[1] === 0 || colTotals[0] === 0 || colTotals[1] === 0) {
    throw new Error('每一行和每一列都至少需要一个有效频数')
  }

  const expected = [
    [
      (rowTotals[0] * colTotals[0]) / total,
      (rowTotals[0] * colTotals[1]) / total
    ],
    [
      (rowTotals[1] * colTotals[0]) / total,
      (rowTotals[1] * colTotals[1]) / total
    ]
  ]
  const observed = [
    [observedA, observedB],
    [observedC, observedD]
  ]

  const useYates = Boolean(yates)
  let chiSquare = 0
  for (let rowIndex = 0; rowIndex < observed.length; rowIndex += 1) {
    for (let colIndex = 0; colIndex < observed[rowIndex].length; colIndex += 1) {
      const observedValue = observed[rowIndex][colIndex]
      const expectedValue = expected[rowIndex][colIndex]
      if (expectedValue <= 0) {
        throw new Error('当前列联表无法计算卡方值：期望频数存在 0')
      }
      if (useYates) {
        const correctedDelta = Math.max(0, Math.abs(observedValue - expectedValue) - 0.5)
        chiSquare += (correctedDelta * correctedDelta) / expectedValue
      } else {
        const delta = observedValue - expectedValue
        chiSquare += (delta * delta) / expectedValue
      }
    }
  }

  const pValue = complementaryErrorFunction(Math.sqrt(Math.max(chiSquare, 0) / 2))
  const oddsRatioBase = observedB * observedC
  let oddsRatio = Number.NaN
  if (oddsRatioBase === 0) {
    oddsRatio = observedA * observedD > 0 ? Number.POSITIVE_INFINITY : Number.NaN
  } else {
    oddsRatio = (observedA * observedD) / oddsRatioBase
  }

  const warnings = []
  const minExpected = Math.min(...expected[0], ...expected[1])
  if (minExpected < 5) {
    warnings.push('至少有一个单元格期望频数 < 5，卡方近似可能不稳定。')
  }
  if (total < 40) {
    warnings.push('样本量较小（N < 40），建议结合效应量和原始频数解释结果。')
  }

  return {
    observed,
    expected,
    rowTotals,
    colTotals,
    total,
    chiSquare,
    degreesOfFreedom: 1,
    pValue,
    significantAt05: pValue < 0.05,
    significantAt01: pValue < 0.01,
    phi: Math.sqrt(chiSquare / total),
    oddsRatio,
    yatesCorrection: useYates,
    warnings
  }
}

export function searchKWIC(tokenObjects, keyword, leftWindowSize = 5, rightWindowSize = 5, searchOptions = {}) {
  const sourceTokenObjects = Array.isArray(tokenObjects) ? tokenObjects : []
  const { matcher, normalizedQuery, options, error } = buildTokenMatcher(keyword, searchOptions)
  if (error) throw new Error(error)
  if (!normalizedQuery) return []

  const cacheKey = `${normalizedQuery}|${leftWindowSize}|${rightWindowSize}|${serializeSearchOptions(options)}`
  const scopedCache = getOrCreateScopedQueryCache(kwicQueryCache, sourceTokenObjects)
  const cachedRows = getCachedScopedQueryResult(scopedCache, cacheKey)
  if (cachedRows) return cachedRows

  let matchedIndexes = null
  if (options.words && !options.regex) {
    const indexes = getTokenObjectIndexes(sourceTokenObjects)
    matchedIndexes = options.caseSensitive
      ? (indexes.rawTokenIndexMap.get(normalizedQuery) || [])
      : (indexes.tokenIndexMap.get(normalizedQuery.toLowerCase()) || [])
  }

  const results = []
  const collectResultAtIndex = i => {
    const currentTokenObject = sourceTokenObjects[i]
    if (!currentTokenObject) return
    const leftStart = Math.max(0, i - leftWindowSize)
    const leftTokens = sourceTokenObjects.slice(leftStart, i).map(item => item.rawToken || item.token)
    const rightTokens = sourceTokenObjects.slice(i + 1, i + 1 + rightWindowSize).map(item => item.rawToken || item.token)
    results.push({
      left: leftTokens.join(' '),
      node: currentTokenObject.rawToken || currentTokenObject.token,
      right: rightTokens.join(' '),
      leftTokens,
      rightTokens,
      sentenceId: currentTokenObject.sentenceId,
      sentenceTokenIndex: currentTokenObject.sentenceTokenIndex,
      leftWindowSize,
      rightWindowSize,
      originalIndex: results.length
    })
  }

  if (matchedIndexes) {
    for (const index of matchedIndexes) {
      collectResultAtIndex(index)
    }
  } else {
    for (let index = 0; index < sourceTokenObjects.length; index += 1) {
      const currentTokenObject = sourceTokenObjects[index]
      if (!currentTokenObject) continue
      if (!matcher(currentTokenObject.rawToken || currentTokenObject.token)) continue
      collectResultAtIndex(index)
    }
  }
  setScopedQueryResult(scopedCache, cacheKey, results)
  return results
}

export function searchLibraryKWIC(corpusEntries, keyword, leftWindowSize = 5, rightWindowSize = 5, searchOptions = {}) {
  const { normalizedQuery, error } = buildTokenMatcher(keyword, searchOptions)
  if (error) throw new Error(error)
  if (!normalizedQuery) return []

  const results = []
  for (const corpusEntry of Array.isArray(corpusEntries) ? corpusEntries : []) {
    const content = String(corpusEntry?.content || '').trim()
    if (!content) continue

    const corpusData = buildCorpusData(content)
    const corpusResults = searchKWIC(corpusData.tokenObjects, keyword, leftWindowSize, rightWindowSize, searchOptions)

    for (const item of corpusResults) {
      results.push({
        ...item,
        corpusId: String(corpusEntry.corpusId || ''),
        corpusName: String(corpusEntry.corpusName || ''),
        folderId: String(corpusEntry.folderId || ''),
        folderName: String(corpusEntry.folderName || ''),
        sourceType: String(corpusEntry.sourceType || 'txt'),
        originalIndex: results.length
      })
    }
  }

  return results
}

export function compareSortToken(a, b) {
  if (!a && !b) return 0
  if (!a) return 1
  if (!b) return -1
  return a.localeCompare(b, 'en', { sensitivity: 'base', numeric: true })
}

export function compareTokenArrays(arrA, arrB) {
  const maxLen = Math.max(arrA.length, arrB.length)
  for (let i = 0; i < maxLen; i++) {
    const result = compareSortToken(arrA[i], arrB[i])
    if (result !== 0) return result
  }
  return 0
}

export function getSortedKWICResults(results, mode) {
  const rows = results.slice()
  rows.sort((a, b) => {
    const aLeftNear = a.leftTokens.slice().reverse()
    const bLeftNear = b.leftTokens.slice().reverse()
    const aRightNear = a.rightTokens.slice()
    const bRightNear = b.rightTokens.slice()
    let result = 0

    if (mode === 'left-near') {
      result = compareTokenArrays(aLeftNear, bLeftNear)
    } else if (mode === 'right-near') {
      result = compareTokenArrays(aRightNear, bRightNear)
    } else if (mode === 'left-then-right') {
      result = compareTokenArrays(aLeftNear, bLeftNear)
      if (result === 0) result = compareTokenArrays(aRightNear, bRightNear)
    } else if (mode === 'right-then-left') {
      result = compareTokenArrays(aRightNear, bRightNear)
      if (result === 0) result = compareTokenArrays(aLeftNear, bLeftNear)
    } else {
      result = a.originalIndex - b.originalIndex
    }

    if (result !== 0) return result
    return a.originalIndex - b.originalIndex
  })
  return rows
}

export function buildTokenFrequencyMap(tokens) {
  return countWordFrequency(tokens)
}

export function searchCollocates(
  tokenObjects,
  tokens,
  keyword,
  leftWindowSize = 5,
  rightWindowSize = 5,
  minFreq = 1,
  searchOptions = {}
) {
  const sourceTokenObjects = Array.isArray(tokenObjects) ? tokenObjects : []
  const { matcher, normalizedQuery, options, error } = buildTokenMatcher(keyword, searchOptions)
  if (error) throw new Error(error)
  if (!normalizedQuery) return []

  const getTokenKey = item => {
    if (!item) return ''
    return options.caseSensitive ? String(item.rawToken || item.token || '') : String(item.token || item.rawToken || '').toLowerCase()
  }

  const cacheKey = `${normalizedQuery}|${leftWindowSize}|${rightWindowSize}|${minFreq}|${serializeSearchOptions(options)}`
  const scopedCache = getOrCreateScopedQueryCache(collocateQueryCache, sourceTokenObjects)
  const cachedRows = getCachedScopedQueryResult(scopedCache, cacheKey)
  if (cachedRows) return cachedRows

  const globalFreqMap = getCollocateGlobalFrequencyMap(sourceTokenObjects, options.caseSensitive)
  const indexes = options.words && !options.regex ? getTokenObjectIndexes(sourceTokenObjects) : null
  const matchedIndexes = indexes
    ? (
        options.caseSensitive
          ? (indexes.rawTokenIndexMap.get(normalizedQuery) || [])
          : (indexes.tokenIndexMap.get(normalizedQuery.toLowerCase()) || [])
      )
    : null

  let keywordFreq = 0
  if (matchedIndexes) {
    keywordFreq = matchedIndexes.length
  } else {
    for (const item of sourceTokenObjects) {
      if (matcher(item.rawToken || item.token)) keywordFreq += 1
    }
  }
  if (keywordFreq === 0) return []

  const collocateMap = {}
  const processTargetIndex = i => {
    const currentToken = sourceTokenObjects[i]
    if (!currentToken) return
    const nodeKey = getTokenKey(currentToken)
    const leftStart = Math.max(0, i - leftWindowSize)
    for (let j = leftStart; j < i; j++) {
      const word = getTokenKey(sourceTokenObjects[j])
      if (!word || word === nodeKey) continue
      if (!collocateMap[word]) {
        collocateMap[word] = {
          word,
          total: 0,
          left: 0,
          right: 0,
          wordFreq: globalFreqMap[word] || 0,
          keywordFreq
        }
      }
      collocateMap[word].total += 1
      collocateMap[word].left += 1
    }

    const rightEnd = Math.min(sourceTokenObjects.length, i + 1 + rightWindowSize)
    for (let j = i + 1; j < rightEnd; j++) {
      const word = getTokenKey(sourceTokenObjects[j])
      if (!word || word === nodeKey) continue
      if (!collocateMap[word]) {
        collocateMap[word] = {
          word,
          total: 0,
          left: 0,
          right: 0,
          wordFreq: globalFreqMap[word] || 0,
          keywordFreq
        }
      }
      collocateMap[word].total += 1
      collocateMap[word].right += 1
    }
  }

  if (matchedIndexes) {
    for (const index of matchedIndexes) {
      processTargetIndex(index)
    }
  } else {
    for (let index = 0; index < sourceTokenObjects.length; index += 1) {
      const currentToken = sourceTokenObjects[index]
      if (!currentToken) continue
      if (!matcher(currentToken.rawToken || currentToken.token)) continue
      processTargetIndex(index)
    }
  }

  const resultRows = Object.values(collocateMap)
    .filter(item => item.total >= minFreq)
    .map(item => ({
      ...item,
      rate: item.keywordFreq === 0 ? 0 : item.total / item.keywordFreq
    }))
    .sort((a, b) => {
      if (b.total !== a.total) return b.total - a.total
      if (b.rate !== a.rate) return b.rate - a.rate
      return a.word.localeCompare(b.word)
    })

  setScopedQueryResult(scopedCache, cacheKey, resultRows)
  return resultRows
}
