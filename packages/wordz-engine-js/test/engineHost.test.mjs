import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'

import { ENGINE_METHODS } from '../../wordz-contracts/src/index.mjs'
import { createEngineHost } from '../src/engineHost.mjs'

async function withTempDir(run) {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'wordz-engine-test-'))
  try {
    return await run(tempDir)
  } finally {
    await fs.rm(tempDir, { recursive: true, force: true })
  }
}

test('engine host returns app info and persists workspace state', async () => {
  await withTempDir(async userDataDir => {
    const host = createEngineHost({ userDataDir })
    const infoResponse = await host.handleRequest({
      jsonrpc: '2.0',
      id: 1,
      method: ENGINE_METHODS.appGetInfo,
      params: {}
    })
    assert.equal(infoResponse.result.success, true)
    assert.equal(infoResponse.result.appInfo.name, 'WordZ')

    const saveResponse = await host.handleRequest({
      jsonrpc: '2.0',
      id: 2,
      method: ENGINE_METHODS.workspaceSaveState,
      params: {
        snapshot: {
          currentTab: 'kwic',
          workspace: {
            corpusIds: ['abc'],
            corpusNames: ['demo']
          }
        }
      }
    })
    assert.equal(saveResponse.result.success, true)
    assert.equal(saveResponse.result.snapshot.currentTab, 'kwic')

    const readResponse = await host.handleRequest({
      jsonrpc: '2.0',
      id: 3,
      method: ENGINE_METHODS.workspaceGetState,
      params: {}
    })
    assert.equal(readResponse.result.success, true)
    assert.equal(readResponse.result.snapshot.workspace.corpusIds[0], 'abc')

    await host.dispose()
  })
})

test('analysis task runner emits completion notifications', async () => {
  await withTempDir(async userDataDir => {
    const host = createEngineHost({ userDataDir })
    const notifications = []
    const unsubscribe = host.onNotification(notification => {
      notifications.push(notification)
    })

    const response = await host.handleRequest({
      jsonrpc: '2.0',
      id: 10,
      method: ENGINE_METHODS.analysisStartTask,
      params: {
        taskType: 'stats',
        payload: {
          text: 'Cyber security is about cyber defense.'
        }
      }
    })

    assert.equal(response.result.success, true)
    assert.ok(response.result.taskId)

    await new Promise(resolve => setTimeout(resolve, 250))
    const completedNotification = notifications.find(item => item.method === 'task.completed')
    assert.ok(completedNotification)
    assert.ok(Array.isArray(completedNotification.params.result.freqRows))

    unsubscribe()
    await host.dispose()
  })
})
