#!/usr/bin/env node
import { createEngineHost } from './engineHost.mjs'
import { createJsonRpcServer } from './jsonRpcServer.mjs'

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

const host = createEngineHost(parseArgs())
createJsonRpcServer({ host })
