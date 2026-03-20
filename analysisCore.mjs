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
      parts.push({ text: partText, isWord: true, norm: partText.toLowerCase(), wordIndex })
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
      tokenObjects.push({ token, sentenceId: sentence.id, sentenceTokenIndex: i })
      tokens.push(token)
    }
  }

  return { sentences, tokenObjects, tokens }
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

export function searchKWIC(tokenObjects, keyword, leftWindowSize = 5, rightWindowSize = 5) {
  const results = []
  for (let i = 0; i < tokenObjects.length; i++) {
    if (tokenObjects[i].token !== keyword) continue
    const leftStart = Math.max(0, i - leftWindowSize)
    const leftTokens = tokenObjects.slice(leftStart, i).map(item => item.token)
    const rightTokens = tokenObjects.slice(i + 1, i + 1 + rightWindowSize).map(item => item.token)
    results.push({
      left: leftTokens.join(' '),
      node: tokenObjects[i].token,
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

export function searchLibraryKWIC(corpusEntries, keyword, leftWindowSize = 5, rightWindowSize = 5) {
  const normalizedKeyword = String(keyword || '').trim().toLowerCase()
  if (!normalizedKeyword) return []

  const results = []
  for (const corpusEntry of Array.isArray(corpusEntries) ? corpusEntries : []) {
    const content = String(corpusEntry?.content || '').trim()
    if (!content) continue

    const corpusData = buildCorpusData(content)
    const corpusResults = searchKWIC(corpusData.tokenObjects, normalizedKeyword, leftWindowSize, rightWindowSize)

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

export function searchCollocates(tokenObjects, tokens, keyword, leftWindowSize = 5, rightWindowSize = 5, minFreq = 1) {
  const globalFreqMap = buildTokenFrequencyMap(tokens)
  const keywordFreq = globalFreqMap[keyword] || 0
  if (keywordFreq === 0) return []

  const collocateMap = {}
  for (let i = 0; i < tokenObjects.length; i++) {
    if (tokenObjects[i].token !== keyword) continue

    const leftStart = Math.max(0, i - leftWindowSize)
    for (let j = leftStart; j < i; j++) {
      const word = tokenObjects[j].token
      if (word === keyword) continue
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
      const word = tokenObjects[j].token
      if (word === keyword) continue
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
