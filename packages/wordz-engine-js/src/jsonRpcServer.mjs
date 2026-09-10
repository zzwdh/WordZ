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
  const handleUncaughtException = uncaughtError => {
    error.write(`[wordz-engine-js] uncaughtException: ${uncaughtError instanceof Error ? uncaughtError.stack || uncaughtError.message : String(uncaughtError)}\n`)
  }
  const handleUnhandledRejection = unhandledReason => {
    error.write(`[wordz-engine-js] unhandledRejection: ${unhandledReason instanceof Error ? unhandledReason.stack || unhandledReason.message : String(unhandledReason)}\n`)
  }
  let cleanupPromise = null

  process.on('uncaughtException', handleUncaughtException)
  process.on('unhandledRejection', handleUnhandledRejection)

  function cleanup() {
    if (cleanupPromise) return cleanupPromise
    cleanupPromise = (async () => {
      process.removeListener('uncaughtException', handleUncaughtException)
      process.removeListener('unhandledRejection', handleUnhandledRejection)
      unsubscribe?.()
      await host.dispose?.()
    })()
    return cleanupPromise
  }

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

  rl.once('close', () => {
    void cleanup()
  })

  return {
    close: async () => {
      rl.close()
      await cleanup()
    }
  }
}
