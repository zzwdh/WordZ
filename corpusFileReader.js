const fs = require('fs/promises')
const path = require('path')
const { isUtf8 } = require('node:buffer')
const iconv = require('iconv-lite')
const mammoth = require('mammoth')

let cachedPDFParseClass = null

const SUPPORTED_CORPUS_EXTENSIONS = new Set(['.txt', '.docx', '.pdf'])
const DEFAULT_PREFLIGHT_OPTIONS = Object.freeze({
  warningSizeBytes: 20 * 1024 * 1024,
  blockingSizeBytes: 200 * 1024 * 1024,
  txtSampleBytes: 8192,
  txtBinaryZeroByteRatio: 0.01,
  txtBinaryControlRatio: 0.25
})

const UTF8_BOM = Buffer.from([0xef, 0xbb, 0xbf])
const UTF16LE_BOM = Buffer.from([0xff, 0xfe])
const UTF16BE_BOM = Buffer.from([0xfe, 0xff])
const LEGACY_TEXT_ENCODINGS = ['gb18030', 'big5']

function ensurePdfRuntimeGlobals() {
  let canvasModule = null
  try {
    canvasModule = require('@napi-rs/canvas')
  } catch {
    return
  }

  const runtimeGlobals = [
    ['DOMMatrix', canvasModule.DOMMatrix],
    ['ImageData', canvasModule.ImageData],
    ['Path2D', canvasModule.Path2D]
  ]

  for (const [globalName, globalValue] of runtimeGlobals) {
    if (typeof globalThis[globalName] === 'undefined' && globalValue) {
      globalThis[globalName] = globalValue
    }
  }
}

function getPDFParseClass() {
  if (cachedPDFParseClass) return cachedPDFParseClass

  ensurePdfRuntimeGlobals()

  const pdfParseModule = require('pdf-parse')
  if (typeof pdfParseModule?.PDFParse !== 'function') {
    throw new Error('PDF 解析器初始化失败：未找到可用的 PDFParse 构造器')
  }

  cachedPDFParseClass = pdfParseModule.PDFParse
  return cachedPDFParseClass
}

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
  const PDFParseClass = getPDFParseClass()
  const parser = new PDFParseClass({ data: buffer })

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

function normalizePreflightOptions(options = {}) {
  const warningSizeBytes = Number(options?.warningSizeBytes)
  const blockingSizeBytes = Number(options?.blockingSizeBytes)
  const txtSampleBytes = Number(options?.txtSampleBytes)
  const txtBinaryZeroByteRatio = Number(options?.txtBinaryZeroByteRatio)
  const txtBinaryControlRatio = Number(options?.txtBinaryControlRatio)

  return {
    warningSizeBytes:
      Number.isFinite(warningSizeBytes) && warningSizeBytes > 0
        ? Math.floor(warningSizeBytes)
        : DEFAULT_PREFLIGHT_OPTIONS.warningSizeBytes,
    blockingSizeBytes:
      Number.isFinite(blockingSizeBytes) && blockingSizeBytes > 0
        ? Math.floor(blockingSizeBytes)
        : DEFAULT_PREFLIGHT_OPTIONS.blockingSizeBytes,
    txtSampleBytes:
      Number.isFinite(txtSampleBytes) && txtSampleBytes > 0
        ? Math.floor(txtSampleBytes)
        : DEFAULT_PREFLIGHT_OPTIONS.txtSampleBytes,
    txtBinaryZeroByteRatio:
      Number.isFinite(txtBinaryZeroByteRatio) && txtBinaryZeroByteRatio > 0
        ? txtBinaryZeroByteRatio
        : DEFAULT_PREFLIGHT_OPTIONS.txtBinaryZeroByteRatio,
    txtBinaryControlRatio:
      Number.isFinite(txtBinaryControlRatio) && txtBinaryControlRatio > 0
        ? txtBinaryControlRatio
        : DEFAULT_PREFLIGHT_OPTIONS.txtBinaryControlRatio
  }
}

function inspectTextSampleBuffer(buffer, options = {}) {
  const sampleBuffer = Buffer.isBuffer(buffer) ? buffer : Buffer.alloc(0)
  if (sampleBuffer.length === 0) {
    return {
      zeroByteRatio: 0,
      controlCharRatio: 0,
      likelyBinary: false
    }
  }

  let zeroByteCount = 0
  let controlCharCount = 0

  for (let index = 0; index < sampleBuffer.length; index += 1) {
    const byte = sampleBuffer[index]
    if (byte === 0) zeroByteCount += 1
    if ((byte >= 1 && byte <= 8) || byte === 11 || byte === 12 || (byte >= 14 && byte <= 31) || byte === 127) {
      controlCharCount += 1
    }
  }

  const zeroByteRatio = zeroByteCount / sampleBuffer.length
  const controlCharRatio = controlCharCount / sampleBuffer.length
  const likelyBinary =
    zeroByteRatio >= options.txtBinaryZeroByteRatio ||
    controlCharRatio >= options.txtBinaryControlRatio

  return {
    zeroByteRatio,
    controlCharRatio,
    likelyBinary
  }
}

async function inspectCorpusFilePreflight(filePath, options = {}) {
  const normalizedPath = String(filePath || '').trim()
  const ext = path.extname(normalizedPath).toLowerCase()
  const normalizedOptions = normalizePreflightOptions(options)
  const result = {
    ok: true,
    filePath: normalizedPath,
    fileName: path.basename(normalizedPath),
    extension: ext,
    sourceType: ext === '.docx' ? 'docx' : ext === '.pdf' ? 'pdf' : 'txt',
    sizeBytes: 0,
    warnings: [],
    errors: [],
    details: {}
  }

  if (!normalizedPath) {
    result.errors.push('路径不能为空')
    result.ok = false
    return result
  }

  if (!SUPPORTED_CORPUS_EXTENSIONS.has(ext)) {
    result.errors.push(`不支持的文件类型：${ext || '(无扩展名)'}`)
    result.ok = false
    return result
  }

  let stats
  try {
    stats = await fs.stat(normalizedPath)
  } catch (error) {
    result.errors.push(error?.message || '文件不可读取')
    result.ok = false
    return result
  }

  if (!stats.isFile()) {
    result.errors.push('仅支持导入文件，当前路径不是普通文件')
    result.ok = false
    return result
  }

  result.sizeBytes = Number(stats.size) || 0

  if (result.sizeBytes <= 0) {
    result.errors.push('文件为空，无法导入')
    result.ok = false
    return result
  }

  if (result.sizeBytes >= normalizedOptions.blockingSizeBytes) {
    result.errors.push(
      `文件体积过大（${Math.round(result.sizeBytes / 1024 / 1024)} MB），已超过导入上限 ${Math.round(normalizedOptions.blockingSizeBytes / 1024 / 1024)} MB`
    )
    result.ok = false
    return result
  }

  if (result.sizeBytes >= normalizedOptions.warningSizeBytes) {
    result.warnings.push(
      `文件较大（${Math.round(result.sizeBytes / 1024 / 1024)} MB），导入与分析可能耗时较长`
    )
  }

  if (ext === '.txt') {
    const fileHandle = await fs.open(normalizedPath, 'r')
    try {
      const sampleSize = Math.min(normalizedOptions.txtSampleBytes, result.sizeBytes)
      const sampleBuffer = Buffer.alloc(sampleSize)
      await fileHandle.read(sampleBuffer, 0, sampleSize, 0)
      const inspectDetails = inspectTextSampleBuffer(sampleBuffer, normalizedOptions)
      result.details.textSample = inspectDetails
      if (inspectDetails.likelyBinary) {
        result.warnings.push('该 txt 文件疑似包含较多二进制控制字符，导入结果可能异常')
      }
    } finally {
      await fileHandle.close().catch(() => {})
    }
  }

  return result
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
  inspectCorpusFilePreflight,
  normalizeCorpusText,
  normalizePdfText,
  readCorpusFile
}
