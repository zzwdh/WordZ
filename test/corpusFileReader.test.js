const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('fs/promises')
const os = require('os')
const path = require('path')
const iconv = require('iconv-lite')
const { buildSimplePdfBuffer } = require('../support/pdfFixture')

const { decodeTxtBuffer, readCorpusFile } = require('../corpusFileReader')

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
