const test = require('node:test')
const assert = require('node:assert/strict')

const {
  createSystemNotificationController,
  normalizeNotificationAction,
  normalizeNotificationPayload
} = require('../main/helpers/systemNotifications')

test('normalizeNotificationPayload trims and bounds notification fields', () => {
  const payload = normalizeNotificationPayload({
    title: `  ${'统计完成'.repeat(20)}  `,
    body: ` ${'导出成功 '.repeat(60)} `,
    subtitle: '  WordZ  ',
    tag: '  export-finished  ',
    silent: true
  }, 'WordZ')

  assert.ok(payload.title.length <= 80)
  assert.ok(payload.body.length <= 240)
  assert.equal(payload.subtitle, 'WordZ')
  assert.equal(payload.tag, 'export-finished')
  assert.equal(payload.silent, true)
})

test('normalizeNotificationPayload falls back to app name when title is empty', () => {
  const payload = normalizeNotificationPayload({
    title: '   ',
    body: '统计已完成'
  }, 'WordZ')

  assert.equal(payload.title, 'WordZ')
  assert.equal(payload.body, '统计已完成')
})

test('normalizeNotificationAction supports string and object input', () => {
  const actionFromString = normalizeNotificationAction(' open-stats-tab ')
  assert.deepEqual(actionFromString, {
    id: 'open-stats-tab',
    payload: null
  })

  const actionFromObject = normalizeNotificationAction({
    actionId: 'reveal-path',
    payload: { path: '/tmp/report.md' }
  })
  assert.deepEqual(actionFromObject, {
    id: 'reveal-path',
    payload: { path: '/tmp/report.md' }
  })

  assert.equal(normalizeNotificationAction({ actionId: '   ' }), null)
})

test('createSystemNotificationController reports unsupported environments cleanly', () => {
  const observed = []
  const controller = createSystemNotificationController({
    NotificationClass: { isSupported: () => false },
    onShow: event => observed.push(event)
  })

  const result = controller.showNotification({
    title: '统计完成',
    body: 'Token 100'
  })

  assert.equal(result.success, false)
  assert.equal(result.supported, false)
  assert.equal(observed.length, 1)
  assert.equal(observed[0].payload.title, '统计完成')
})

test('createSystemNotificationController shows notifications and emits observer payloads', () => {
  const shown = []
  const observed = []
  const observedActions = []
  class FakeNotification {
    static isSupported() {
      return true
    }

    constructor(options) {
      this.options = options
      this.clickHandler = null
    }

    once(eventName, handler) {
      if (eventName === 'click') this.clickHandler = handler
    }

    show() {
      shown.push(this.options)
      this.clickHandler?.()
    }
  }

  const controller = createSystemNotificationController({
    NotificationClass: FakeNotification,
    appName: 'WordZ',
    onShow: event => observed.push(event),
    onAction: event => observedActions.push(event)
  })

  const result = controller.showNotification({
    title: '  KWIC 检索完成 ',
    body: ' 共 12 条结果 ',
    tag: 'kwic-finished',
    action: {
      actionId: 'open-kwic-tab',
      payload: { tab: 'kwic' }
    }
  })

  assert.equal(result.success, true)
  assert.equal(shown.length, 1)
  assert.equal(shown[0].title, 'KWIC 检索完成')
  assert.equal(shown[0].body, '共 12 条结果')
  assert.equal(observed.length, 1)
  assert.equal(observed[0].payload.tag, 'kwic-finished')
  assert.equal(observed[0].result.success, true)
  assert.equal(observedActions.length, 1)
  assert.equal(observedActions[0].actionId, 'open-kwic-tab')
  assert.equal(observedActions[0].tag, 'kwic-finished')
  assert.deepEqual(observedActions[0].actionPayload, { tab: 'kwic' })
})
