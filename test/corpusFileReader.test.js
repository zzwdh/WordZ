const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('fs/promises')
const os = require('os')
const path = require('path')
const iconv = require('iconv-lite')
const { buildSimplePdfBuffer } = require('../support/pdfFixture')

const { decodeTxtBuffer, inspectCorpusFilePreflight, readCorpusFile } = require('../corpusFileReader')

async function createTempDir(t) {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'wordz-file-reader-'))
  t.after(async () => {
    await fs.rm(tempDir, { recursive: true, force: true })
  })
  return tempDir
}

test('decodeTxtBuffer keeps utf-8 text stable', () => {
  const input = Buffer.from('rose bloom bright\nline two', 'utf8')
  const result = decodeTxtBuffer(input)

  assert.equal(result.encoding, 'utf8')
  assert.equal(result.content, 'rose bloom bright\nline two')
})

test('decodeTxtBuffer detects gb18030 chinese text', () => {
  const input = iconv.encode('春天 花开 研究 词频', 'gb18030')
  const result = decodeTxtBuffer(input)

  assert.equal(result.encoding, 'gb18030')
  assert.equal(result.content, '春天 花开 研究 词频')
})

test('readCorpusFile supports utf16 little-endian txt files', async t => {
  const tempDir = await createTempDir(t)
  const filePath = path.join(tempDir, 'utf16le-sample.txt')
  const bomBuffer = Buffer.from([0xff, 0xfe])
  const utf16Content = Buffer.from('Alpha Beta', 'utf16le')

  await fs.writeFile(filePath, Buffer.concat([bomBuffer, utf16Content]))

  const result = await readCorpusFile(filePath)
  assert.equal(result.encoding, 'utf16le')
  assert.equal(result.content, 'Alpha Beta')
})

test('readCorpusFile reads gb18030 txt files end-to-end', async t => {
  const tempDir = await createTempDir(t)
  const filePath = path.join(tempDir, 'gb18030-sample.txt')
  await fs.writeFile(filePath, iconv.encode('春天 花开 词频 分析', 'gb18030'))

  const result = await readCorpusFile(filePath)
  assert.equal(result.encoding, 'gb18030')
  assert.equal(result.content, '春天 花开 词频 分析')
})

test('readCorpusFile reads pdf files end-to-end', async t => {
  const tempDir = await createTempDir(t)
  const filePath = path.join(tempDir, 'sample.pdf')
  await fs.writeFile(filePath, buildSimplePdfBuffer(['rose bloom bright', 'second line']))

  const result = await readCorpusFile(filePath)
  assert.equal(result.encoding, 'pdf')
  assert.equal(result.content, 'rose bloom bright\nsecond line')
})

test('inspectCorpusFilePreflight blocks empty files', async t => {
  const tempDir = await createTempDir(t)
  const filePath = path.join(tempDir, 'empty.txt')
  await fs.writeFile(filePath, '')

  const result = await inspectCorpusFilePreflight(filePath)
  assert.equal(result.ok, false)
  assert.equal(result.errors.length > 0, true)
  assert.match(result.errors[0], /文件为空/)
})

test('inspectCorpusFilePreflight warns for likely binary txt sample', async t => {
  const tempDir = await createTempDir(t)
  const filePath = path.join(tempDir, 'binary-like.txt')
  await fs.writeFile(filePath, Buffer.from([0, 1, 2, 3, 4, 0, 7, 9, 10, 13, 0, 255]))

  const result = await inspectCorpusFilePreflight(filePath)
  assert.equal(result.ok, true)
  assert.equal(result.warnings.length > 0, true)
  assert.match(result.warnings[0], /二进制/)
})

test('inspectCorpusFilePreflight supports custom size limits', async t => {
  const tempDir = await createTempDir(t)
  const filePath = path.join(tempDir, 'large.txt')
  await fs.writeFile(filePath, Buffer.alloc(2048, 65))

  const warningResult = await inspectCorpusFilePreflight(filePath, {
    warningSizeBytes: 1024,
    blockingSizeBytes: 4096
  })
  assert.equal(warningResult.ok, true)
  assert.equal(warningResult.warnings.length > 0, true)

  const blockedResult = await inspectCorpusFilePreflight(filePath, {
    warningSizeBytes: 1024,
    blockingSizeBytes: 1025
  })
  assert.equal(blockedResult.ok, false)
  assert.equal(blockedResult.errors.length > 0, true)
  assert.match(blockedResult.errors[0], /文件体积过大/)
})
