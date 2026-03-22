import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import { _electron as electron } from 'playwright-core'

const require = createRequire(import.meta.url)
const __dirname = path.dirname(fileURLToPath(import.meta.url))
const appRoot = path.resolve(__dirname, '..')
const distDir = path.join(appRoot, 'dist')
const packageManifest = require(path.join(appRoot, 'package.json'))
const APP_NAME = packageManifest.productName || packageManifest.name || 'WordZ'
const APP_CLOSE_TIMEOUT_MS = 5000
const PACKAGED_SMOKE_TIMEOUT_MS = 45000
const STARTUP_LOG_PATH = path.join(os.tmpdir(), 'wordz-startup-crash.log')

function buildIsolatedEnv(homeDir, extraEnv = {}) {
  return {
    ...process.env,
    HOME: homeDir,
    APPDATA: homeDir,
    XDG_CONFIG_HOME: path.join(homeDir, '.config'),
    XDG_CACHE_HOME: path.join(homeDir, '.cache'),
    CORPUS_LITE_SMOKE_USER_DATA_DIR: path.join(homeDir, 'user-data'),
    CORPUS_LITE_DISABLE_SINGLE_INSTANCE: '1',
    ...extraEnv
  }
}

async function pathExists(targetPath) {
  try {
    await fs.access(targetPath)
    return true
  } catch {
    return false
  }
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

async function forceCloseElectronApp(electronApp) {
  if (!electronApp) return

  const childProcess = typeof electronApp.process === 'function' ? electronApp.process() : null

  try {
    await electronApp.evaluate(async ({ app }) => {
      app.quit()
    })
  } catch {}

  try {
    await electronApp.waitForEvent('close', { timeout: APP_CLOSE_TIMEOUT_MS })
    return
  } catch {}

  if (childProcess && childProcess.exitCode === null && !childProcess.killed) {
    childProcess.kill('SIGKILL')
  }

  try {
    await Promise.race([
      electronApp.waitForEvent('close', { timeout: APP_CLOSE_TIMEOUT_MS }),
      delay(APP_CLOSE_TIMEOUT_MS)
    ])
  } catch {}
}

async function resolvePackagedExecutable() {
  if (process.platform === 'darwin') {
    const entries = await fs.readdir(distDir, { withFileTypes: true }).catch(() => [])
    const macBuildDirs = entries
      .filter(entry => entry.isDirectory() && /^mac-/i.test(entry.name))
      .map(entry => entry.name)
      .sort()

    for (const buildDir of macBuildDirs) {
      const executablePath = path.join(distDir, buildDir, `${APP_NAME}.app`, 'Contents', 'MacOS', APP_NAME)
      if (await pathExists(executablePath)) {
        return executablePath
      }
    }
  }

  if (process.platform === 'win32') {
    const executablePath = path.join(distDir, 'win-unpacked', `${APP_NAME}.exe`)
    if (await pathExists(executablePath)) {
      return executablePath
    }
  }

  throw new Error(`未找到当前平台的打包应用，请先执行对应 dist 构建。平台：${process.platform}`)
}

async function readStartupLogTail() {
  try {
    const text = await fs.readFile(STARTUP_LOG_PATH, 'utf8')
    return text.trim().split('\n').slice(-80).join('\n')
  } catch {
    return ''
  }
}

async function waitForPackagedSmokeResult(resultPath, timeoutMs = PACKAGED_SMOKE_TIMEOUT_MS) {
  const startedAt = Date.now()
  while (Date.now() - startedAt < timeoutMs) {
    try {
      const text = await fs.readFile(resultPath, 'utf8')
      const parsed = JSON.parse(text)
      if (parsed && typeof parsed === 'object') {
        return parsed
      }
    } catch {}
    await delay(250)
  }

  const startupLogTail = await readStartupLogTail()
  const logSuffix = startupLogTail ? `\n\n最近启动日志：\n${startupLogTail}` : ''
  throw new Error(`打包态 smoke 未在 ${timeoutMs}ms 内写出结果文件：${resultPath}${logSuffix}`)
}

async function runPackagedSmokeScenario(t, {
  extraEnv = {},
  expectedCompatProfile = ''
} = {}) {
  const executablePath = await resolvePackagedExecutable()
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'wordz-packaged-smoke-'))
  const fixturePath = path.join(tempHome, 'packaged-smoke.txt')
  const resultPath = path.join(tempHome, 'packaged-smoke-result.json')
  let electronApp = null

  await fs.writeFile(
    fixturePath,
    [
      'rose red rose bloom bright',
      'rose bloom bright bloom rose',
      'bloom red rose bright bloom'
    ].join('\n'),
    'utf-8'
  )
  await fs.rm(STARTUP_LOG_PATH, { force: true }).catch(() => {})

  t.after(async () => {
    if (electronApp) {
      await forceCloseElectronApp(electronApp)
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await electron.launch({
    executablePath,
    cwd: path.dirname(executablePath),
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath]),
      CORPUS_LITE_PACKAGED_SMOKE_AUTORUN: '1',
      CORPUS_LITE_PACKAGED_SMOKE_RESULT_PATH: resultPath,
      ...extraEnv
    })
  })

  const runtimeInfo = await electronApp.evaluate(async ({ app }) => ({
    isPackaged: app.isPackaged,
    appPath: app.getAppPath(),
    version: app.getVersion()
  }))

  assert.equal(runtimeInfo.isPackaged, true)
  assert.match(String(runtimeInfo.appPath || ''), /app\.asar/i)
  assert.equal(runtimeInfo.version, packageManifest.version)

  const smokeResult = await waitForPackagedSmokeResult(resultPath)

  assert.equal(smokeResult.status, 'passed')
  assert.equal(smokeResult.corpusName, 'packaged-smoke')
  assert.ok(Number(smokeResult.statsRowCount) > 0)
  assert.ok(Number(smokeResult.kwicResultCount) > 0)
  assert.equal(smokeResult.runtime?.searchQuery, 'rose')
  if (expectedCompatProfile) {
    const startupLogTail = await readStartupLogTail()
    assert.match(startupLogTail, new RegExp(`"compatProfile":\\s*"${expectedCompatProfile}"`))
  }
}

test('Packaged smoke: bundled app launches from app.asar and runs quick-open analysis', {
  timeout: 120000,
  skip: process.platform !== 'darwin' && process.platform !== 'win32'
}, async t => {
  await runPackagedSmokeScenario(t)
})

test('Packaged smoke: Windows compat no-sandbox override launches successfully', {
  timeout: 120000,
  skip: process.platform !== 'win32'
}, async t => {
  await runPackagedSmokeScenario(t, {
    extraEnv: {
      WORDZ_WINDOWS_COMPAT_PROFILE: 'no-sandbox'
    },
    expectedCompatProfile: 'no-sandbox'
  })
})

test('Packaged smoke: Windows compat no-sandbox-no-rci override launches successfully', {
  timeout: 120000,
  skip: process.platform !== 'win32'
}, async t => {
  await runPackagedSmokeScenario(t, {
    extraEnv: {
      WORDZ_WINDOWS_COMPAT_PROFILE: 'no-sandbox-no-rci'
    },
    expectedCompatProfile: 'no-sandbox-no-rci'
  })
})
