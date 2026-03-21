const test = require('node:test')
const assert = require('node:assert/strict')

const { createWindowAttentionController } = require('../main/helpers/windowAttention')

test('window attention applies and clears Windows overlay icons', () => {
  const overlayCalls = []
  const fakeWindow = {
    isDestroyed: () => false,
    setOverlayIcon(icon, description) {
      overlayCalls.push({
        icon,
        description
      })
    }
  }
  const fakeNativeImage = {
    createFromDataURL() {
      return {
        isEmpty: () => false,
        resize: () => ({ __kind: 'overlay-icon' })
      }
    }
  }

  const controller = createWindowAttentionController({
    platform: 'win32',
    nativeImage: fakeNativeImage,
    getWindows: () => [fakeWindow],
    appName: 'WordZ'
  })

  controller.updateSource('task-center', {
    count: 3,
    description: '统计结果已完成',
    priority: 30
  })
  controller.clearSource('task-center')

  assert.equal(overlayCalls.length, 2)
  assert.equal(overlayCalls[0].description, '统计结果已完成')
  assert.ok(overlayCalls[0].icon)
  assert.equal(overlayCalls[1].icon, null)
  assert.equal(overlayCalls[1].description, '')
})

test('window attention updates macOS dock badge and bounces once under throttle', () => {
  const badgeCalls = []
  const bounceCalls = []
  const appliedEvents = []
  const fakeApp = {
    dock: {
      setBadge(value) {
        badgeCalls.push(value)
      },
      bounce(type) {
        bounceCalls.push(type)
        return bounceCalls.length
      }
    }
  }

  const controller = createWindowAttentionController({
    platform: 'darwin',
    app: fakeApp,
    onApply: event => appliedEvents.push(event)
  })

  controller.updateSource('task-center', {
    count: 1,
    description: 'KWIC 检索完成',
    priority: 20,
    requestAttention: true
  })
  controller.updateSource('task-center', {
    count: 2,
    description: 'Collocate 统计完成',
    priority: 20,
    requestAttention: true
  })
  controller.clearAll()

  assert.deepEqual(badgeCalls, ['1', '2', ''])
  assert.equal(bounceCalls.length, 1)
  assert.equal(bounceCalls[0], 'informational')
  assert.equal(appliedEvents[0].winningEntry.source, 'task-center')
  assert.equal(appliedEvents[0].winningEntry.count, 1)
  assert.equal(appliedEvents.at(-1).winningEntry, null)
})
