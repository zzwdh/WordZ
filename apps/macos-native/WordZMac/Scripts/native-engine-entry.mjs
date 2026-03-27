#!/usr/bin/env node
import { createEngineHost } from '../../../../packages/wordz-engine-js/src/engineHost.mjs'
import { createJsonRpcServer } from '../../../../packages/wordz-engine-js/src/jsonRpcServer.mjs'
import {
  ENGINE_METHODS,
  JSON_RPC_VERSION
} from '../../../../packages/wordz-contracts/src/index.mjs'

function parseArgs(argv = process.argv.slice(2)) {
  const pendingLaunchFilePaths = []
  let userDataDir = ''

  for (const arg of argv) {
    const value = String(arg || '').trim()
    if (!value) continue
    if (value.startsWith('--user-data-dir=')) {
      userDataDir = value.slice('--user-data-dir='.length)
      continue
    }
    if (value.startsWith('--open-path=')) {
      pendingLaunchFilePaths.push(value.slice('--open-path='.length))
      continue
    }
    pendingLaunchFilePaths.push(value)
  }

  return {
    pendingLaunchFilePaths,
    userDataDir
  }
}

function emit(method, params = {}) {
  process.stdout.write(`${JSON.stringify({
    jsonrpc: JSON_RPC_VERSION,
    method,
    params
  })}\n`)
}

async function assertMethodReady(host, method, params = {}) {
  const response = await host.handleRequest({
    jsonrpc: JSON_RPC_VERSION,
    id: `startup-${method}`,
    method,
    params
  })
  if (response?.error?.message) {
    throw new Error(`[${method}] ${response.error.message}`)
  }
  if (response?.result?.success === false) {
    throw new Error(`[${method}] ${response.result.message || '引擎启动检查失败'}`)
  }
}

async function bootstrap() {
  const host = createEngineHost(parseArgs())
  createJsonRpcServer({ host })

  try {
    await assertMethodReady(host, ENGINE_METHODS.appGetInfo)
    await assertMethodReady(host, ENGINE_METHODS.libraryList, { folderId: 'all' })
    await assertMethodReady(host, ENGINE_METHODS.workspaceGetState)
    await assertMethodReady(host, ENGINE_METHODS.workspaceGetUiSettings)

    emit('engine.ready', {
      stage: 'ready',
      checks: [
        ENGINE_METHODS.appGetInfo,
        ENGINE_METHODS.libraryList,
        ENGINE_METHODS.workspaceGetState,
        ENGINE_METHODS.workspaceGetUiSettings
      ]
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error || '引擎启动失败')
    emit('engine.startupError', {
      stage: 'bootstrap',
      error: message
    })
    process.stderr.write(`[wordz-mac-native] startupError: ${message}\n`)
    process.exitCode = 1
    setTimeout(() => process.exit(1), 10)
  }
}

bootstrap()
