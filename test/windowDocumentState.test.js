const test = require('node:test')
const assert = require('node:assert/strict')

const {
  createWindowDocumentStateController,
  normalizeWindowDocumentState
} = require('../main/helpers/windowDocumentState')

test('normalizeWindowDocumentState resolves represented path and title', () => {
  const state = normalizeWindowDocumentState(
    {
      representedPath: './fixtures/demo.txt',
      displayName: '  Demo Corpus  ',
      edited: true
    },
    {
      appName: 'WordZ'
    }
  )

  assert.match(state.representedPath, /fixtures\/demo\.txt$/)
  assert.equal(state.displayName, 'Demo Corpus')
  assert.equal(state.edited, true)
  assert.equal(state.windowTitle, 'WordZ — Demo Corpus')
})

test('window document controller applies represented file and edited dot on mac', () => {
  const calls = []
  const fakeWindow = {
    destroyed: false,
    isDestroyed() {
      return this.destroyed
    },
    setRepresentedFilename(value) {
      calls.push(['represented', value])
    },
    setDocumentEdited(value) {
      calls.push(['edited', value])
    },
    setTitle(value) {
      calls.push(['title', value])
    }
  }

  const controller = createWindowDocumentStateController({
    win: fakeWindow,
    platform: 'darwin',
    appName: 'WordZ'
  })

  controller.update({
    representedPath: '/tmp/example.txt',
    displayName: 'Example Corpus',
    edited: true
  })

  assert.deepEqual(calls.slice(-3), [
    ['represented', '/tmp/example.txt'],
    ['edited', true],
    ['title', 'WordZ — Example Corpus']
  ])
})

test('window document controller clears represented file when payload is empty', () => {
  const calls = []
  const fakeWindow = {
    isDestroyed() {
      return false
    },
    setRepresentedFilename(value) {
      calls.push(['represented', value])
    },
    setDocumentEdited(value) {
      calls.push(['edited', value])
    },
    setTitle(value) {
      calls.push(['title', value])
    }
  }

  const controller = createWindowDocumentStateController({
    win: fakeWindow,
    platform: 'darwin',
    appName: 'WordZ'
  })

  controller.update({
    representedPath: '/tmp/example.txt',
    displayName: 'Example Corpus',
    edited: true
  })
  controller.clear()

  assert.deepEqual(calls.slice(-3), [
    ['represented', ''],
    ['edited', false],
    ['title', 'WordZ']
  ])
})
