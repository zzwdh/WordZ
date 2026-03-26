const test = require('node:test')
const assert = require('node:assert/strict')

const { createDialogController } = require('../main/helpers/dialogSupport')

test('dialog controller attaches open dialogs to mac windows as sheets', async () => {
  const calls = []
  const parentWindow = {
    isDestroyed() {
      return false
    }
  }
  const controller = createDialogController({
    dialog: {
      showOpenDialog(...args) {
        calls.push(args)
        return Promise.resolve({ canceled: false, filePaths: ['/tmp/demo.txt'] })
      }
    },
    getParentWindow: () => parentWindow,
    platform: 'darwin'
  })

  const result = await controller.showOpenDialog({
    properties: ['openFile']
  })

  assert.equal(result.canceled, false)
  assert.deepEqual(calls, [[parentWindow, { properties: ['openFile'] }]])
})

test('dialog controller falls back to unbound dialogs on non-mac platforms', async () => {
  const calls = []
  const controller = createDialogController({
    dialog: {
      showSaveDialog(...args) {
        calls.push(args)
        return Promise.resolve({ canceled: false, filePath: '/tmp/demo.txt' })
      }
    },
    getParentWindow: () => ({
      isDestroyed() {
        return false
      }
    }),
    platform: 'linux'
  })

  const result = await controller.showSaveDialog({
    defaultPath: 'demo.txt'
  })

  assert.equal(result.canceled, false)
  assert.deepEqual(calls, [[{ defaultPath: 'demo.txt' }]])
})
