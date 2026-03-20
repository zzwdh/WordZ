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
  for (const partText of matches) {
    const isWord = /^[\p{L}\p{N}']+$/u.test(partText)
    if (isWord) {
      parts.push({ text: partText, isWord: true, rawToken: partText, norm: partText.toLowerCase(), wordIndex })
      wordIndex += 1
    } else {
      parts.push({ text: partText, isWord: false })
    }
  }
  return { parts, normalizedTokens: parts.filter(part => part.isWord).map(part => part.norm) }
}

export function buildCorpusData(text) {
  const sentenceTexts = splitTextIntoSentences(text)
  const sentences = sentenceTexts.map((sentenceText, index) => {
    const parsed = parseSentenceParts(sentenceText)
    return { id: index, text: sentenceText, parts: parsed.parts, normalizedTokens: parsed.normalizedTokens }
  })

  const tokenObjects = []
  const tokens = []
  for (const sentence of sentences) {
    for (let i = 0; i < sentence.normalizedTokens.length; i++) {
      const token = sentence.normalizedTokens[i]
      const rawToken = sentence.parts.find(part => part.isWord && part.wordIndex === i)?.rawToken || token
      tokenObjects.push({ token, rawToken, sentenceId: sentence.id, sentenceTokenIndex: i })
      tokens.push(token)
    }
  }

  return { sentences, tokenObjects, tokens }
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
  const freqMap = {}
  for (const token of tokens) {
    if (!freqMap[token]) freqMap[token] = 0
    freqMap[token] += 1
  }
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
    const topEntry = getSortedFrequencyRows(freqMap)[0] || ['', 0]

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
      topWord: topEntry[0],
      topWordCount: topEntry[1],
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

export function searchKWIC(tokenObjects, keyword, leftWindowSize = 5, rightWindowSize = 5, searchOptions = {}) {
  const { matcher, normalizedQuery, error } = buildTokenMatcher(keyword, searchOptions)
  if (error) throw new Error(error)
  if (!normalizedQuery) return []

  const results = []
  for (let i = 0; i < tokenObjects.length; i++) {
    if (!matcher(tokenObjects[i].rawToken || tokenObjects[i].token)) continue
    const leftStart = Math.max(0, i - leftWindowSize)
    const leftTokens = tokenObjects.slice(leftStart, i).map(item => item.rawToken || item.token)
    const rightTokens = tokenObjects.slice(i + 1, i + 1 + rightWindowSize).map(item => item.rawToken || item.token)
    results.push({
      left: leftTokens.join(' '),
      node: tokenObjects[i].rawToken || tokenObjects[i].token,
      right: rightTokens.join(' '),
      leftTokens,
      rightTokens,
      sentenceId: tokenObjects[i].sentenceId,
      sentenceTokenIndex: tokenObjects[i].sentenceTokenIndex,
      leftWindowSize,
      rightWindowSize,
      originalIndex: results.length
    })
  }
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
  const freqMap = {}
  for (const token of tokens) {
    if (!freqMap[token]) freqMap[token] = 0
    freqMap[token] += 1
  }
  return freqMap
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
  const { matcher, normalizedQuery, options, error } = buildTokenMatcher(keyword, searchOptions)
  if (error) throw new Error(error)
  if (!normalizedQuery) return []

  const getTokenKey = item => {
    if (!item) return ''
    return options.caseSensitive ? String(item.rawToken || item.token || '') : String(item.token || item.rawToken || '').toLowerCase()
  }

  const globalFreqMap = {}
  for (const item of Array.isArray(tokenObjects) ? tokenObjects : []) {
    const key = getTokenKey(item)
    if (!key) continue
    if (!globalFreqMap[key]) globalFreqMap[key] = 0
    globalFreqMap[key] += 1
  }

  let keywordFreq = 0
  for (const item of Array.isArray(tokenObjects) ? tokenObjects : []) {
    if (matcher(item.rawToken || item.token)) keywordFreq += 1
  }
  if (keywordFreq === 0) return []

  const collocateMap = {}
  for (let i = 0; i < tokenObjects.length; i++) {
    if (!matcher(tokenObjects[i].rawToken || tokenObjects[i].token)) continue

    const leftStart = Math.max(0, i - leftWindowSize)
    for (let j = leftStart; j < i; j++) {
      const word = getTokenKey(tokenObjects[j])
      if (!word || word === getTokenKey(tokenObjects[i])) continue
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

    const rightEnd = Math.min(tokenObjects.length, i + 1 + rightWindowSize)
    for (let j = i + 1; j < rightEnd; j++) {
      const word = getTokenKey(tokenObjects[j])
      if (!word || word === getTokenKey(tokenObjects[i])) continue
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

  return Object.values(collocateMap)
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
}
