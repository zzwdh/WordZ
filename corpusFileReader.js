const fs = require('fs/promises')
const path = require('path')
const { isUtf8 } = require('node:buffer')
const iconv = require('iconv-lite')
const mammoth = require('mammoth')
const { PDFParse } = require('pdf-parse')

const UTF8_BOM = Buffer.from([0xef, 0xbb, 0xbf])
const UTF16LE_BOM = Buffer.from([0xff, 0xfe])
const UTF16BE_BOM = Buffer.from([0xfe, 0xff])
const LEGACY_TEXT_ENCODINGS = ['gb18030', 'big5']

function normalizeCorpusText(text) {
  return String(text || '')
    .replace(/^\uFEFF/, '')
    .replace(/\r\n?/g, '\n')
    .trim()
}

function detectBomEncoding(buffer) {
  if (buffer.subarray(0, UTF8_BOM.length).equals(UTF8_BOM)) {
    return { encoding: 'utf8', bomLength: UTF8_BOM.length }
  }

  if (buffer.subarray(0, UTF16LE_BOM.length).equals(UTF16LE_BOM)) {
    return { encoding: 'utf16le', bomLength: UTF16LE_BOM.length }
  }

  if (buffer.subarray(0, UTF16BE_BOM.length).equals(UTF16BE_BOM)) {
    return { encoding: 'utf16be', bomLength: UTF16BE_BOM.length }
  }

  return null
}

function detectUtf16Encoding(buffer) {
  if (buffer.length < 4 || buffer.length % 2 !== 0) return ''

  const samplePairs = Math.min(Math.floor(buffer.length / 2), 64)
  let evenNulls = 0
  let oddNulls = 0

  for (let index = 0; index < samplePairs; index += 1) {
    if (buffer[index * 2] === 0) evenNulls += 1
    if (buffer[index * 2 + 1] === 0) oddNulls += 1
  }

  const evenNullRatio = evenNulls / samplePairs
  const oddNullRatio = oddNulls / samplePairs

  if (oddNullRatio >= 0.3 && evenNullRatio <= 0.05) return 'utf16le'
  if (evenNullRatio >= 0.3 && oddNullRatio <= 0.05) return 'utf16be'

  return ''
}

function decodeUtf16BeBuffer(buffer) {
  const evenLength = buffer.length - (buffer.length % 2)
  if (evenLength <= 0) return ''
  return Buffer.from(buffer.subarray(0, evenLength)).swap16().toString('utf16le')
}

function decodeBufferWithEncoding(buffer, encoding) {
  if (encoding === 'utf8') return buffer.toString('utf8')
  if (encoding === 'utf16le') return buffer.toString('utf16le')
  if (encoding === 'utf16be') return decodeUtf16BeBuffer(buffer)
  return iconv.decode(buffer, encoding)
}

function countUnexpectedControlChars(text) {
  const matches = text.match(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/g)
  return matches ? matches.length : 0
}

function countReplacementChars(text) {
  const matches = text.match(/\uFFFD/g)
  return matches ? matches.length : 0
}

function countMatchingBytes(left, right) {
  const limit = Math.min(left.length, right.length)
  let matched = 0
  for (let index = 0; index < limit; index += 1) {
    if (left[index] !== right[index]) break
    matched += 1
  }
  return matched
}

function scoreLegacyDecodedText(decodedText, originalBuffer, encoding) {
  const reEncoded = iconv.encode(decodedText, encoding)
  const matchingBytes = countMatchingBytes(reEncoded, originalBuffer)
  const replacementCount = countReplacementChars(decodedText)
  const controlCount = countUnexpectedControlChars(decodedText)

  let score = matchingBytes * 2
  score -= Math.abs(reEncoded.length - originalBuffer.length) * 4
  score -= replacementCount * 120
  score -= controlCount * 40
  score += Math.min(decodedText.length, 40)

  return score
}

function detectLegacyEncoding(buffer) {
  let bestMatch = {
    encoding: LEGACY_TEXT_ENCODINGS[0],
    text: decodeBufferWithEncoding(buffer, LEGACY_TEXT_ENCODINGS[0]),
    score: Number.NEGATIVE_INFINITY
  }

  for (const encoding of LEGACY_TEXT_ENCODINGS) {
    const text = decodeBufferWithEncoding(buffer, encoding)
    const score = scoreLegacyDecodedText(text, buffer, encoding)

    if (score > bestMatch.score) {
      bestMatch = { encoding, text, score }
    }
  }

  return {
    encoding: bestMatch.encoding,
    text: bestMatch.text
  }
}

function decodeTxtBuffer(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0) {
    return {
      content: '',
      encoding: 'utf8'
    }
  }

  const bomEncoding = detectBomEncoding(buffer)
  if (bomEncoding) {
    return {
      content: normalizeCorpusText(decodeBufferWithEncoding(buffer.subarray(bomEncoding.bomLength), bomEncoding.encoding)),
      encoding: bomEncoding.encoding
    }
  }

  const utf16Encoding = detectUtf16Encoding(buffer)
  if (utf16Encoding) {
    return {
      content: normalizeCorpusText(decodeBufferWithEncoding(buffer, utf16Encoding)),
      encoding: utf16Encoding
    }
  }

  if (typeof isUtf8 === 'function' && isUtf8(buffer)) {
    return {
      content: normalizeCorpusText(buffer.toString('utf8')),
      encoding: 'utf8'
    }
  }

  const legacyMatch = detectLegacyEncoding(buffer)
  return {
    content: normalizeCorpusText(legacyMatch.text),
    encoding: legacyMatch.encoding
  }
}

function normalizePdfText(text) {
  return normalizeCorpusText(String(text || '').replace(/\n--\s+\d+\s+of\s+\d+\s+--\n?/g, '\n'))
}

async function extractPdfText(buffer) {
  const parser = new PDFParse({ data: buffer })

  try {
    const result = await parser.getText()
    return {
      content: normalizePdfText(result?.text || ''),
      encoding: 'pdf'
    }
  } finally {
    await parser.destroy().catch(() => {})
  }
}

async function readCorpusFile(filePath) {
  const ext = path.extname(filePath).toLowerCase()

  if (ext === '.txt') {
    return decodeTxtBuffer(await fs.readFile(filePath))
  }

  if (ext === '.docx') {
    const result = await mammoth.extractRawText({ path: filePath })
    return {
      content: normalizeCorpusText(result.value),
      encoding: 'docx'
    }
  }

  if (ext === '.pdf') {
    return extractPdfText(await fs.readFile(filePath))
  }

  throw new Error('不支持的文件类型：' + ext)
}

module.exports = {
  decodeTxtBuffer,
  detectLegacyEncoding,
  detectUtf16Encoding,
  extractPdfText,
  normalizeCorpusText,
  normalizePdfText,
  readCorpusFile
}
