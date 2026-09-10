import test from 'node:test'
import assert from 'node:assert/strict'

import { createAnalysisTaskRunner } from '../src/analysisTaskRunner.mjs'

async function waitForEventLoop() {
  await new Promise(resolve => setTimeout(resolve, 30))
}

test('cancelling a running analysis task never emits a failed terminal state', async () => {
  const runner = createAnalysisTaskRunner()
  const notifications = []
  const unsubscribe = runner.onNotification(notification => {
    notifications.push(notification)
  })

  try {
    const started = runner.startTask('stats', {
      text: 'alpha beta gamma delta '.repeat(250000)
    })
    const cancelled = await runner.cancelTask(started.taskId)
    await waitForEventLoop()

    assert.equal(cancelled.status, 'cancelled')
    assert.equal(runner.getTaskState(started.taskId).status, 'cancelled')
    assert.equal(
      notifications.some(item => item.method === 'task.failed' && item.params?.taskId === started.taskId),
      false
    )
    assert.equal(
      notifications.filter(item => item.method === 'task.cancelled' && item.params?.taskId === started.taskId).length,
      1
    )
  } finally {
    unsubscribe()
    await runner.dispose()
  }
})
