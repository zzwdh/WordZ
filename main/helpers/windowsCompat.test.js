const test = require('node:test')
const assert = require('node:assert/strict')
const fsSync = require('node:fs')
const fs = require('node:fs/promises')
const os = require('node:os')
const path = require('node:path')

const {
  createWindowsCompatController,
  normalizeWindowsCompatProfile
} = require('./windowsCompat')

function createFakeApp(userDataDir) {
  return {
    getPath(targetName) {
      assert.equal(targetName, 'userData')
      return userDataDir
    }
  }
}

async function createController(options = {}) {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'wordz-windows-compat-test-'))
  const controller = createWindowsCompatController({
    app: createFakeApp(tempDir),
    fs,
    fsSync,
    path,
    logger: { warn() {} },
    appendEarlyCrashLog() {},
    ...options
  })
  return {
    controller,
    tempDir
  }
}

test('normalizeWindowsCompatProfile falls back to standard for invalid values', () => {
  assert.equal(normalizeWindowsCompatProfile('standard'), 'standard')
  assert.equal(normalizeWindowsCompatProfile('NO-SANDBOX'), 'no-sandbox')
  assert.equal(normalizeWindowsCompatProfile('bad-profile'), 'standard')
  assert.equal(normalizeWindowsCompatProfile(''), 'standard')
})

test('Windows compat controller prefers env override over persisted state', async t => {
  const { controller, tempDir } = await createController({
    envProfile: 'no-sandbox-no-rci'
  })

  t.after(async () => {
    await fs.rm(tempDir, { recursive: true, force: true })
  })

  const snapshot = controller.getSnapshot()
  if (!snapshot.supported) {
    t.skip('Windows compat controller is only supported on win32')
    return
  }

  assert.equal(snapshot.compatProfile, 'no-sandbox-no-rci')
  assert.equal(snapshot.compatProfileSource, 'env-override')
  assert.equal(snapshot.rendererSandboxDisabled, true)
  assert.equal(snapshot.rendererCodeIntegrityDisabled, true)
})

test('Windows compat controller supports launch-arg session override with persistence intent', async t => {
  const { controller, tempDir } = await createController({
    launchArgProfile: 'no-sandbox',
    launchArgPersistEligible: true
  })

  t.after(async () => {
    await fs.rm(tempDir, { recursive: true, force: true })
  })

  const snapshot = controller.getSnapshot()
  if (!snapshot.supported) {
    t.skip('Windows compat controller is only supported on win32')
    return
  }

  const launchConfig = controller.beginWindowLaunchContext()
  assert.equal(snapshot.compatProfile, 'no-sandbox')
  assert.equal(snapshot.compatProfileSource, 'session-override')
  assert.equal(launchConfig.persistEligible, true)
  assert.equal(launchConfig.rendererSandboxDisabled, true)
})

test('Windows compat crash promotion follows standard -> no-sandbox -> no-sandbox-no-rci -> safe-fallback', async t => {
  const { controller, tempDir } = await createController()

  t.after(async () => {
    await fs.rm(tempDir, { recursive: true, force: true })
  })

  if (!controller.isSupported()) {
    t.skip('Windows compat controller is only supported on win32')
    return
  }

  controller.beginWindowLaunchContext()
  let resolution = await controller.recordCrashAndResolveNextProfile({
    reason: 'crashed',
    exitCode: -1
  })
  assert.equal(resolution.currentProfile, 'standard')
  assert.equal(resolution.nextProfile, 'no-sandbox')

  controller.beginWindowLaunchContext()
  resolution = await controller.recordCrashAndResolveNextProfile({
    reason: 'crashed',
    exitCode: -2
  })
  assert.equal(resolution.currentProfile, 'no-sandbox')
  assert.equal(resolution.nextProfile, 'no-sandbox-no-rci')

  controller.beginWindowLaunchContext()
  resolution = await controller.recordCrashAndResolveNextProfile({
    reason: 'crashed',
    exitCode: -3
  })
  assert.equal(resolution.currentProfile, 'no-sandbox-no-rci')
  assert.equal(resolution.nextProfile, 'safe-fallback')
  assert.equal(resolution.useSafeFallback, true)

  const snapshot = controller.getSnapshot()
  assert.equal(snapshot.compatProfile, 'safe-fallback')
  assert.equal(snapshot.persistedProfile, 'safe-fallback')
  assert.equal(snapshot.lastCrash?.reason, 'crashed')
  assert.equal(snapshot.lastCrash?.exitCode, -3)
  assert.equal(snapshot.useSafeFallback, true)
  assert.equal(snapshot.rendererSandboxDisabled, false)
  assert.equal(snapshot.rendererCodeIntegrityDisabled, false)
})

test('Windows compat stable launches roll back one level after three successful exits', async t => {
  const { controller, tempDir } = await createController({
    launchArgProfile: 'no-sandbox-no-rci',
    launchArgPersistEligible: true
  })

  t.after(async () => {
    await fs.rm(tempDir, { recursive: true, force: true })
  })

  if (!controller.isSupported()) {
    t.skip('Windows compat controller is only supported on win32')
    return
  }

  for (let index = 0; index < 3; index += 1) {
    controller.beginWindowLaunchContext()
    controller.markMainUiLoaded()
    await controller.markNormalExit()
  }

  const snapshot = controller.getSnapshot()
  assert.equal(snapshot.persistedProfile, 'no-sandbox')
  assert.equal(snapshot.compatProfile, 'no-sandbox')
  assert.equal(snapshot.stableLaunchCount, 0)
  assert.equal(snapshot.compatProfileResetReason, 'auto-stable-rollback')
})

test('Windows compat reset clears persisted fallback state', async t => {
  const { controller, tempDir } = await createController()

  t.after(async () => {
    await fs.rm(tempDir, { recursive: true, force: true })
  })

  if (!controller.isSupported()) {
    t.skip('Windows compat controller is only supported on win32')
    return
  }

  controller.beginWindowLaunchContext()
  await controller.recordCrashAndResolveNextProfile({ reason: 'crashed', exitCode: -1 })
  controller.beginWindowLaunchContext()
  await controller.recordCrashAndResolveNextProfile({ reason: 'crashed', exitCode: -2 })
  controller.beginWindowLaunchContext()
  await controller.recordCrashAndResolveNextProfile({ reason: 'crashed', exitCode: -3 })

  let snapshot = controller.getSnapshot()
  assert.equal(snapshot.persistedProfile, 'safe-fallback')

  await controller.clearPersistedState('manual-reset')
  controller.clearSessionOverride()
  snapshot = controller.getSnapshot()
  assert.equal(snapshot.persistedProfile, 'standard')
  assert.equal(snapshot.compatProfile, 'standard')
  assert.equal(snapshot.compatProfileResetReason, 'manual-reset')
})

test('Windows compat stable manual recovery promotes working profile out of safe fallback', async t => {
  const { controller, tempDir } = await createController()

  t.after(async () => {
    await fs.rm(tempDir, { recursive: true, force: true })
  })

  if (!controller.isSupported()) {
    t.skip('Windows compat controller is only supported on win32')
    return
  }

  controller.beginWindowLaunchContext()
  await controller.recordCrashAndResolveNextProfile({ reason: 'crashed', exitCode: -1 })
  controller.beginWindowLaunchContext()
  await controller.recordCrashAndResolveNextProfile({ reason: 'crashed', exitCode: -2 })
  controller.beginWindowLaunchContext()
  await controller.recordCrashAndResolveNextProfile({ reason: 'crashed', exitCode: -3 })

  let snapshot = controller.getSnapshot()
  assert.equal(snapshot.persistedProfile, 'safe-fallback')

  controller.beginProfileLaunchContext('standard', {
    source: 'manual-attempt',
    persistEligible: false
  })
  snapshot = await controller.reportRendererStable({ stage: 'startup-complete' })
  assert.equal(snapshot.persistedProfile, 'standard')
  assert.equal(snapshot.compatProfile, 'standard')
  assert.equal(snapshot.compatProfileResetReason, 'manual-recovery-success')

  await controller.markNormalExit()
  snapshot = controller.getSnapshot()
  assert.equal(snapshot.stableLaunchCount, 1)
})

test('Windows compat runtime crash fallback forces persisted safe fallback state', async t => {
  const { controller, tempDir } = await createController({
    launchArgProfile: 'standard',
    launchArgPersistEligible: true
  })

  t.after(async () => {
    await fs.rm(tempDir, { recursive: true, force: true })
  })

  if (!controller.isSupported()) {
    t.skip('Windows compat controller is only supported on win32')
    return
  }

  controller.beginWindowLaunchContext()
  await controller.reportRendererStable({ stage: 'startup-complete' })
  const snapshot = await controller.enterSafeFallback({
    profile: 'standard',
    reason: 'crashed-after-stable',
    exitCode: -1073741819
  })

  assert.equal(snapshot.persistedProfile, 'safe-fallback')
  assert.equal(snapshot.compatProfile, 'safe-fallback')
  assert.equal(snapshot.lastCrash?.profile, 'standard')
  assert.equal(snapshot.lastCrash?.reason, 'crashed-after-stable')
  assert.equal(snapshot.compatProfileResetReason, 'runtime-crash-fallback')
})
