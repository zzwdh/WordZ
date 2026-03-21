const test = require('node:test')
const assert = require('node:assert/strict')

const {
  extractLaunchAction,
  extractLaunchFilePaths,
  normalizeSupportedCorpusFilePath
} = require('../main/helpers/fileOpenSupport')

test('normalizeSupportedCorpusFilePath keeps supported corpus extensions and rejects unsupported input', () => {
  assert.match(normalizeSupportedCorpusFilePath('/tmp/demo.txt'), /demo\.txt$/)
  assert.match(normalizeSupportedCorpusFilePath('/tmp/demo.docx'), /demo\.docx$/)
  assert.equal(normalizeSupportedCorpusFilePath('/tmp/demo.csv'), '')
  assert.equal(normalizeSupportedCorpusFilePath('--flag'), '')
})

test('extractLaunchFilePaths finds supported corpus paths from process argv style arrays', () => {
  const filePaths = extractLaunchFilePaths([
    '/Applications/WordZ.app/Contents/MacOS/WordZ',
    '/Users/demo/project',
    '/tmp/alpha.txt',
    '--inspect',
    '/tmp/beta.pdf',
    '/tmp/alpha.txt'
  ])

  assert.equal(filePaths.length, 2)
  assert.match(filePaths[0], /alpha\.txt$/)
  assert.match(filePaths[1], /beta\.pdf$/)
})

test('extractLaunchAction parses supported launch actions from argv', () => {
  assert.equal(
    extractLaunchAction([
      '/Applications/WordZ.app/Contents/MacOS/WordZ',
      '--wordz-action=open-quick-corpus'
    ]),
    'open-quick-corpus'
  )

  assert.equal(
    extractLaunchAction([
      '/Applications/WordZ.app/Contents/MacOS/WordZ',
      '--wordz-action',
      'import-and-save-corpus'
    ]),
    'import-and-save-corpus'
  )

  assert.equal(
    extractLaunchAction([
      '/Applications/WordZ.app/Contents/MacOS/WordZ',
      '--wordz-action',
      'unknown-action'
    ]),
    ''
  )
})
