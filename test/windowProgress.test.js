const test = require('node:test')
const assert = require('node:assert/strict')

const { createWindowProgressController } = require('../main/helpers/windowProgress')

test('window progress prefers higher-priority determinate sources and clears cleanly', () => {
  const calls = []
  const fakeWindow = {
    isDestroyed: () => false,
    setProgressBar(progress, options) {
      calls.push({ progress, options })
    }
  }

  const controller = createWindowProgressController({
    platform: 'win32',
    getWindows: () => [fakeWindow]
  })

  controller.updateSource('analysis', {
    state: 'indeterminate',
    priority: 10
  })
  controller.updateSource('auto-update', {
    state: 'normal',
    progress: 0.42,
    priority: 90
  })
  controller.clearSource('auto-update')
  controller.clearSource('analysis')

  assert.deepEqual(calls[0], {
    progress: 2,
    options: { mode: 'indeterminate' }
  })
  assert.deepEqual(calls[1], {
    progress: 0.42,
    options: { mode: 'normal' }
  })
  assert.deepEqual(calls[2], {
    progress: 2,
    options: { mode: 'indeterminate' }
  })
  assert.deepEqual(calls[3], {
    progress: -1,
    options: undefined
  })
})

test('window progress emits observer snapshots for macOS-style progress states', () => {
  const applied = []
  const fakeWindow = {
    isDestroyed: () => false,
    setProgressBar() {}
  }

  const controller = createWindowProgressController({
    platform: 'darwin',
    getWindows: () => [fakeWindow],
    onApply: event => applied.push(event)
  })

  controller.updateSource('analysis', {
    state: 'paused',
    progress: 0.5,
    priority: 20
  })
  controller.updateSource('analysis', {
    state: 'error',
    progress: 0.9,
    priority: 20
  })
  controller.clearAll()

  assert.equal(applied.length, 3)
  assert.deepEqual(applied[0], {
    winningEntry: {
      source: 'analysis',
      state: 'paused',
      progress: 0.5,
      priority: 20
    },
    payload: {
      progress: 0.5,
      options: undefined
    },
    activeSourceCount: 1
  })
  assert.deepEqual(applied[1], {
    winningEntry: {
      source: 'analysis',
      state: 'error',
      progress: 0.9,
      priority: 20
    },
    payload: {
      progress: 0.9,
      options: undefined
    },
    activeSourceCount: 1
  })
  assert.deepEqual(applied[2], {
    winningEntry: null,
    payload: {
      progress: -1,
      options: undefined
    },
    activeSourceCount: 0
  })
})
