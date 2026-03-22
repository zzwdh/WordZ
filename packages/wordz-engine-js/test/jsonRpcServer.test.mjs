import test from 'node:test'
import assert from 'node:assert/strict'
import { PassThrough } from 'node:stream'

import { createJsonRpcServer } from '../src/jsonRpcServer.mjs'

function createUtf8Stream() {
  const stream = new PassThrough()
  stream.setEncoding('utf8')
  return stream
}

async function waitForEventLoop() {
  await new Promise(resolve => setTimeout(resolve, 20))
}

test('json rpc server writes responses and notifications', async () => {
  const input = createUtf8Stream()
  const output = createUtf8Stream()
  const error = createUtf8Stream()
  const lines = []
  output.on('data', chunk => {
    lines.push(...String(chunk).split('\n').filter(Boolean))
  })

  let notificationListener = null
  const host = {
    onNotification(listener) {
      notificationListener = listener
      return () => {
        notificationListener = null
      }
    },
    async handleRequest(request) {
      return {
        jsonrpc: '2.0',
        id: request.id,
        result: {
          success: true,
          echo: request.method
        }
      }
    },
    async dispose() {}
  }

  const server = createJsonRpcServer({ host, input, output, error })
  input.write(`${JSON.stringify({ jsonrpc: '2.0', id: 'abc', method: 'ping', params: {} })}\n`)
  await waitForEventLoop()

  notificationListener?.({
    method: 'task.updated',
    params: {
      taskId: 'demo'
    }
  })
  await waitForEventLoop()

  await server.close()

  assert.equal(lines.length, 2)
  const [responseLine, notificationLine] = lines.map(line => JSON.parse(line))
  assert.equal(responseLine.id, 'abc')
  assert.equal(responseLine.result.echo, 'ping')
  assert.equal(notificationLine.method, 'task.updated')
  assert.equal(notificationLine.params.taskId, 'demo')
})

test('json rpc server returns parse errors for invalid json', async () => {
  const input = createUtf8Stream()
  const output = createUtf8Stream()
  const error = createUtf8Stream()
  const lines = []
  output.on('data', chunk => {
    lines.push(...String(chunk).split('\n').filter(Boolean))
  })

  const host = {
    onNotification() {
      return () => {}
    },
    async handleRequest() {
      return null
    },
    async dispose() {}
  }

  const server = createJsonRpcServer({ host, input, output, error })
  input.write('{not-valid-json}\n')
  await waitForEventLoop()
  await server.close()

  assert.equal(lines.length, 1)
  const message = JSON.parse(lines[0])
  assert.equal(message.error.code, -32700)
})
