import readline from 'node:readline'

import {
  ENGINE_ERROR_CODES,
  JSON_RPC_VERSION
} from '../../wordz-contracts/src/index.mjs'

function writeMessage(stream, payload) {
  stream.write(`${JSON.stringify(payload)}\n`)
}

export function createJsonRpcServer({ host, input = process.stdin, output = process.stdout, error = process.stderr }) {
  const rl = readline.createInterface({
    input,
    crlfDelay: Infinity
  })

  const unsubscribe = host.onNotification?.((notification) => {
    writeMessage(output, {
      jsonrpc: JSON_RPC_VERSION,
      method: notification.method,
      params: notification.params ?? null
    })
  })

  rl.on('line', async line => {
    const trimmedLine = String(line || '').trim()
    if (!trimmedLine) return

    let request
    try {
      request = JSON.parse(trimmedLine)
    } catch (parseError) {
      writeMessage(output, {
        jsonrpc: JSON_RPC_VERSION,
        id: null,
        error: {
          code: ENGINE_ERROR_CODES.parseError,
          message: parseError instanceof Error ? parseError.message : 'Parse error'
        }
      })
      return
    }

    try {
      const response = await host.handleRequest(request)
      if (response) {
        writeMessage(output, response)
      }
    } catch (requestError) {
      writeMessage(output, {
        jsonrpc: JSON_RPC_VERSION,
        id: request?.id ?? null,
        error: {
          code: ENGINE_ERROR_CODES.internalError,
          message: requestError instanceof Error ? requestError.message : 'Internal error'
        }
      })
    }
  })

  rl.once('close', async () => {
    unsubscribe?.()
    await host.dispose?.()
  })

  process.on('uncaughtException', uncaughtError => {
    error.write(`[wordz-engine-js] uncaughtException: ${uncaughtError instanceof Error ? uncaughtError.stack || uncaughtError.message : String(uncaughtError)}\n`)
  })

  process.on('unhandledRejection', unhandledReason => {
    error.write(`[wordz-engine-js] unhandledRejection: ${unhandledReason instanceof Error ? unhandledReason.stack || unhandledReason.message : String(unhandledReason)}\n`)
  })

  return {
    close: async () => {
      rl.close()
      unsubscribe?.()
      await host.dispose?.()
    }
  }
}
