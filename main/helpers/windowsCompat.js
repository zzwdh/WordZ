const WINDOWS_COMPAT_PROFILE_ORDER = Object.freeze([
  'standard',
  'no-sandbox',
  'no-sandbox-no-rci',
  'safe-fallback'
])

const WINDOWS_COMPAT_STATE_FILE = 'windows-compat-state.json'
const DEFAULT_STABLE_LAUNCHES_BEFORE_ROLLBACK = 3

function normalizeWindowsCompatProfile(value) {
  const normalizedValue = String(value || '').trim().toLowerCase()
  return WINDOWS_COMPAT_PROFILE_ORDER.includes(normalizedValue) ? normalizedValue : 'standard'
}

function isValidWindowsCompatProfile(value) {
  return WINDOWS_COMPAT_PROFILE_ORDER.includes(String(value || '').trim().toLowerCase())
}

function getWindowsCompatProfileIndex(profile) {
  return WINDOWS_COMPAT_PROFILE_ORDER.indexOf(normalizeWindowsCompatProfile(profile))
}

function getNextWindowsCompatProfile(profile) {
  const profileIndex = getWindowsCompatProfileIndex(profile)
  if (profileIndex < 0 || profileIndex >= WINDOWS_COMPAT_PROFILE_ORDER.length - 1) {
    return WINDOWS_COMPAT_PROFILE_ORDER.at(-1)
  }
  return WINDOWS_COMPAT_PROFILE_ORDER[profileIndex + 1]
}

function getPreviousWindowsCompatProfile(profile) {
  const profileIndex = getWindowsCompatProfileIndex(profile)
  if (profileIndex <= 0) return WINDOWS_COMPAT_PROFILE_ORDER[0]
  return WINDOWS_COMPAT_PROFILE_ORDER[profileIndex - 1]
}

function toFiniteNumber(value, fallbackValue = 0) {
  const numericValue = Number(value)
  return Number.isFinite(numericValue) ? numericValue : fallbackValue
}

function normalizeCrashState(crashState = null) {
  if (!crashState || typeof crashState !== 'object') return null
  const profile = normalizeWindowsCompatProfile(crashState.profile)
  return {
    profile,
    reason: String(crashState.reason || '').trim(),
    exitCode: toFiniteNumber(crashState.exitCode, 0),
    at: String(crashState.at || '').trim()
  }
}

function normalizePersistedState(rawState = null) {
  if (!rawState || typeof rawState !== 'object') {
    return {
      profile: 'standard',
      stableLaunchCount: 0,
      lastCrash: null,
      lastUpdatedAt: '',
      compatProfileResetReason: ''
    }
  }

  return {
    profile: normalizeWindowsCompatProfile(rawState.profile),
    stableLaunchCount: Math.max(0, Math.trunc(toFiniteNumber(rawState.stableLaunchCount, 0))),
    lastCrash: normalizeCrashState(rawState.lastCrash),
    lastUpdatedAt: String(rawState.lastUpdatedAt || '').trim(),
    compatProfileResetReason: String(rawState.compatProfileResetReason || '').trim()
  }
}

function buildLaunchConfig({
  profile,
  source,
  persistEligible = false,
  rendererSandboxDisabled = false,
  disableRendererCodeIntegrity = false,
  useSafeFallback = false,
  preserveGpuDisable = true,
  disablePreload = false
}) {
  return {
    profile: normalizeWindowsCompatProfile(profile),
    source: String(source || 'default').trim() || 'default',
    persistEligible: Boolean(persistEligible),
    rendererSandboxDisabled: Boolean(rendererSandboxDisabled),
    disableRendererCodeIntegrity: Boolean(disableRendererCodeIntegrity),
    useSafeFallback: Boolean(useSafeFallback),
    preserveGpuDisable: Boolean(preserveGpuDisable),
    disablePreload: Boolean(disablePreload)
  }
}

function createWindowsCompatController({
  app,
  fs,
  fsSync,
  path,
  logger = console,
  appendEarlyCrashLog = () => {},
  stableLaunchesBeforeRollback = DEFAULT_STABLE_LAUNCHES_BEFORE_ROLLBACK,
  disableRendererSandboxEnv = false,
  envProfile = '',
  launchArgProfile = '',
  launchArgPersistEligible = false
}) {
  const supported = process.platform === 'win32'
  const userDataDir = typeof app?.getPath === 'function'
    ? app.getPath('userData')
    : process.cwd()
  const stateFilePath = path.join(userDataDir, WINDOWS_COMPAT_STATE_FILE)
  const normalizedDisableSandboxEnv = Boolean(disableRendererSandboxEnv)
  const normalizedEnvProfile = isValidWindowsCompatProfile(envProfile)
    ? normalizeWindowsCompatProfile(envProfile)
    : ''
  const normalizedLaunchArgProfile = isValidWindowsCompatProfile(launchArgProfile)
    ? normalizeWindowsCompatProfile(launchArgProfile)
    : ''
  const normalizedLaunchArgPersistEligible = Boolean(launchArgPersistEligible)
  let persistedState = loadPersistedState()
  let sessionOverride = null
  let currentLaunchContext = null
  let lastEffectiveConfig = null

  function loadPersistedState() {
    if (!supported) {
      return normalizePersistedState()
    }
    try {
      const rawText = fsSync.readFileSync(stateFilePath, 'utf8')
      return normalizePersistedState(JSON.parse(rawText))
    } catch {
      return normalizePersistedState()
    }
  }

  async function persistState(nextState, extraDetails = null) {
    persistedState = normalizePersistedState(nextState)
    if (!supported) return persistedState

    const statePayload = {
      ...persistedState,
      lastUpdatedAt: new Date().toISOString()
    }
    persistedState = statePayload

    try {
      await fs.mkdir(path.dirname(stateFilePath), { recursive: true })
      await fs.writeFile(stateFilePath, JSON.stringify(statePayload, null, 2), 'utf8')
    } catch (error) {
      logger.warn?.('[windows-compat.persist]', error)
    }

    appendEarlyCrashLog('windows.compat.state.persisted', 'windows compatibility state saved', {
      compatProfile: statePayload.profile,
      compatProfileSource: currentLaunchContext?.source || 'persisted',
      stableLaunchCount: statePayload.stableLaunchCount,
      compatProfileResetReason: statePayload.compatProfileResetReason || '',
      ...(extraDetails && typeof extraDetails === 'object' ? extraDetails : {})
    })

    return statePayload
  }

  async function clearPersistedState(resetReason = 'manual-reset') {
    persistedState = normalizePersistedState({
      profile: 'standard',
      stableLaunchCount: 0,
      lastCrash: null,
      compatProfileResetReason: resetReason
    })

    try {
      await fs.rm(stateFilePath, { force: true })
    } catch (error) {
      logger.warn?.('[windows-compat.clear]', error)
    }

    appendEarlyCrashLog('windows.compat.state.cleared', 'windows compatibility state cleared', {
      compatProfile: 'standard',
      compatProfileResetReason: resetReason
    })
    return persistedState
  }

  function resolveProfileSource() {
    if (!supported) return { profile: 'standard', source: 'default' }
    if (normalizedEnvProfile) {
      return {
        profile: normalizedEnvProfile,
        source: 'env-override',
        persistEligible: false
      }
    }
    if (normalizedLaunchArgProfile) {
      return {
        profile: normalizedLaunchArgProfile,
        source: 'session-override',
        persistEligible: normalizedLaunchArgPersistEligible
      }
    }
    if (sessionOverride?.profile) {
      return {
        profile: normalizeWindowsCompatProfile(sessionOverride.profile),
        source: sessionOverride.source || 'session-override',
        persistEligible: Boolean(sessionOverride.persistEligible)
      }
    }
    if (persistedState.profile && persistedState.profile !== 'standard') {
      return {
        profile: normalizeWindowsCompatProfile(persistedState.profile),
        source: 'persisted',
        persistEligible: true
      }
    }
    return {
      profile: 'standard',
      source: 'default',
      persistEligible: true
    }
  }

  function buildEffectiveLaunchConfig() {
    const { profile, source, persistEligible = false } = resolveProfileSource()
    if (!supported) {
      return buildLaunchConfig({
        profile: 'standard',
        source: 'default',
        persistEligible: true,
        rendererSandboxDisabled: normalizedDisableSandboxEnv
      })
    }

    if (profile === 'safe-fallback') {
      return buildLaunchConfig({
        profile,
        source,
        persistEligible,
        rendererSandboxDisabled: false,
        disableRendererCodeIntegrity: false,
        useSafeFallback: true,
        disablePreload: true
      })
    }

    if (profile === 'no-sandbox-no-rci') {
      return buildLaunchConfig({
        profile,
        source,
        persistEligible,
        rendererSandboxDisabled: true,
        disableRendererCodeIntegrity: true
      })
    }

    if (profile === 'no-sandbox') {
      return buildLaunchConfig({
        profile,
        source,
        persistEligible,
        rendererSandboxDisabled: true
      })
    }

    return buildLaunchConfig({
      profile: 'standard',
      source,
      persistEligible,
      rendererSandboxDisabled: normalizedDisableSandboxEnv
    })
  }

  function buildLaunchConfigForProfile(
    profile,
    {
      source = 'session-override',
      persistEligible = false
    } = {}
  ) {
    const normalizedProfile = normalizeWindowsCompatProfile(profile)
    if (!supported) {
      return buildLaunchConfig({
        profile: 'standard',
        source: 'default',
        persistEligible: true,
        rendererSandboxDisabled: normalizedDisableSandboxEnv
      })
    }

    if (normalizedProfile === 'safe-fallback') {
      return buildLaunchConfig({
        profile: normalizedProfile,
        source,
        persistEligible,
        rendererSandboxDisabled: false,
        disableRendererCodeIntegrity: false,
        useSafeFallback: true,
        disablePreload: true
      })
    }

    if (normalizedProfile === 'no-sandbox-no-rci') {
      return buildLaunchConfig({
        profile: normalizedProfile,
        source,
        persistEligible,
        rendererSandboxDisabled: true,
        disableRendererCodeIntegrity: true
      })
    }

    if (normalizedProfile === 'no-sandbox') {
      return buildLaunchConfig({
        profile: normalizedProfile,
        source,
        persistEligible,
        rendererSandboxDisabled: true
      })
    }

    return buildLaunchConfig({
      profile: 'standard',
      source,
      persistEligible,
      rendererSandboxDisabled: normalizedDisableSandboxEnv
    })
  }

  function beginWindowLaunchContext(extraDetails = null) {
    const launchConfig = buildEffectiveLaunchConfig()
    currentLaunchContext = {
      profile: launchConfig.profile,
      source: launchConfig.source,
      mainUiLoaded: false,
      renderCrashOccurred: false,
      persistEligible: Boolean(launchConfig.persistEligible),
      startedAt: new Date().toISOString(),
      extraDetails: extraDetails && typeof extraDetails === 'object' ? { ...extraDetails } : {}
    }
    lastEffectiveConfig = launchConfig
    return launchConfig
  }

  function beginProfileLaunchContext(
    profile,
    {
      source = 'session-override',
      persistEligible = false,
      extraDetails = null
    } = {}
  ) {
    const launchConfig = buildLaunchConfigForProfile(profile, {
      source,
      persistEligible
    })
    currentLaunchContext = {
      profile: launchConfig.profile,
      source: launchConfig.source,
      mainUiLoaded: false,
      renderCrashOccurred: false,
      persistEligible: Boolean(launchConfig.persistEligible),
      startedAt: new Date().toISOString(),
      extraDetails: extraDetails && typeof extraDetails === 'object' ? { ...extraDetails } : {}
    }
    lastEffectiveConfig = launchConfig
    return launchConfig
  }

  function markMainUiLoaded() {
    if (!currentLaunchContext) return
    currentLaunchContext.mainUiLoaded = true
    appendEarlyCrashLog('windows.compat.main-ui-ready', 'windows compatibility profile reached main UI', {
      compatProfile: currentLaunchContext.profile,
      compatProfileSource: currentLaunchContext.source
    })
  }

  async function reportRendererStable({ stage = 'renderer-ready' } = {}) {
    if (!supported || !currentLaunchContext) {
      return getSnapshot()
    }

    currentLaunchContext.mainUiLoaded = true
    appendEarlyCrashLog('windows.compat.renderer-stable', 'windows compatibility profile reported stable renderer startup', {
      compatProfile: currentLaunchContext.profile,
      compatProfileSource: currentLaunchContext.source,
      stage: String(stage || '').trim() || 'renderer-ready'
    })

    const currentProfile = normalizeWindowsCompatProfile(currentLaunchContext.profile)
    const shouldPersistWorkingProfile =
      currentLaunchContext.source === 'manual-attempt' ||
      currentLaunchContext.source === 'session-override' ||
      normalizeWindowsCompatProfile(persistedState.profile) === 'safe-fallback'

    if (currentProfile === 'safe-fallback' || !shouldPersistWorkingProfile) {
      return getSnapshot()
    }

    await persistState({
      profile: currentProfile,
      stableLaunchCount: 0,
      lastCrash: persistedState.lastCrash,
      compatProfileResetReason: currentLaunchContext.source === 'manual-attempt'
        ? 'manual-recovery-success'
        : 'working-profile-confirmed'
    }, {
      compatProfile: currentProfile,
      compatProfileSource: currentLaunchContext.source,
      compatProfileResetReason: currentLaunchContext.source === 'manual-attempt'
        ? 'manual-recovery-success'
        : 'working-profile-confirmed'
    })

    sessionOverride = null
    currentLaunchContext.source = 'persisted-confirmed'
    currentLaunchContext.persistEligible = true
    return getSnapshot()
  }

  async function markNormalExit() {
    if (!supported || !currentLaunchContext) return
    const activeContext = { ...currentLaunchContext }
    currentLaunchContext = null

    if (!activeContext.mainUiLoaded || activeContext.renderCrashOccurred) {
      return
    }

    if (!activeContext.persistEligible) {
      appendEarlyCrashLog('windows.compat.stable.nonpersistent', 'stable launch completed without persisting compatibility profile', {
        compatProfile: activeContext.profile,
        compatProfileSource: activeContext.source
      })
      return
    }

    const currentProfile = normalizeWindowsCompatProfile(activeContext.profile)
    const previousProfile = normalizeWindowsCompatProfile(persistedState.profile)
    let stableLaunchCount = previousProfile === currentProfile
      ? Math.max(0, Math.trunc(toFiniteNumber(persistedState.stableLaunchCount, 0))) + 1
      : 1
    let nextProfile = currentProfile
    let compatProfilePromotedFrom = ''
    let compatProfileResetReason = ''

    if (
      currentProfile !== 'standard' &&
      currentProfile !== 'safe-fallback' &&
      stableLaunchCount >= stableLaunchesBeforeRollback
    ) {
      compatProfilePromotedFrom = currentProfile
      nextProfile = getPreviousWindowsCompatProfile(currentProfile)
      stableLaunchCount = 0
      compatProfileResetReason = 'auto-stable-rollback'
    }

    await persistState({
      profile: nextProfile,
      stableLaunchCount,
      lastCrash: persistedState.lastCrash,
      compatProfileResetReason
    }, {
      compatProfile: nextProfile,
      compatProfileSource: activeContext.source,
      compatProfilePromotedFrom,
      stableLaunchCount
    })
  }

  async function recordCrashAndResolveNextProfile({ reason = '', exitCode = 0 } = {}) {
    const activeConfig = lastEffectiveConfig || buildEffectiveLaunchConfig()
    const currentProfile = normalizeWindowsCompatProfile(activeConfig.profile)
    const currentSource = String(activeConfig.source || 'default').trim() || 'default'
    const crashState = {
      profile: currentProfile,
      reason: String(reason || '').trim(),
      exitCode: toFiniteNumber(exitCode, 0),
      at: new Date().toISOString()
    }

    if (currentLaunchContext) {
      currentLaunchContext.renderCrashOccurred = true
    }

    appendEarlyCrashLog('windows.compat.crash', 'windows compatibility profile crashed', {
      compatProfile: currentProfile,
      compatProfileSource: currentSource,
      reason: crashState.reason,
      exitCode: crashState.exitCode
    })

    if (currentSource === 'env-override') {
      return {
        currentProfile,
        nextProfile: currentProfile,
        source: currentSource,
        persistFallback: false,
        useSafeFallback: currentProfile === 'safe-fallback',
        crashState
      }
    }

    const nextProfile = getNextWindowsCompatProfile(currentProfile)
    const useSafeFallback = nextProfile === 'safe-fallback'
    sessionOverride = {
      profile: nextProfile,
      source: 'session-override',
      persistEligible: true
    }

    const result = {
      currentProfile,
      nextProfile,
      source: currentSource,
      persistFallback: useSafeFallback,
      useSafeFallback,
      crashState
    }

    if (useSafeFallback) {
      await persistState({
        profile: 'safe-fallback',
        stableLaunchCount: 0,
        lastCrash: crashState,
        compatProfileResetReason: ''
      }, {
        compatProfile: 'safe-fallback',
        compatProfileSource: 'persisted',
        compatProfilePromotedFrom: currentProfile
      })
    } else {
      persistedState = normalizePersistedState({
        ...persistedState,
        lastCrash: crashState,
        stableLaunchCount: 0
      })
    }

    return result
  }

  async function enterSafeFallback({ reason = '', exitCode = 0, profile = '' } = {}) {
    const sourceProfile = normalizeWindowsCompatProfile(profile || lastEffectiveConfig?.profile || persistedState.profile || 'standard')
    const crashState = {
      profile: sourceProfile,
      reason: String(reason || '').trim(),
      exitCode: toFiniteNumber(exitCode, 0),
      at: new Date().toISOString()
    }

    if (currentLaunchContext) {
      currentLaunchContext.renderCrashOccurred = true
    }

    await persistState({
      profile: 'safe-fallback',
      stableLaunchCount: 0,
      lastCrash: crashState,
      compatProfileResetReason: 'runtime-crash-fallback'
    }, {
      compatProfile: 'safe-fallback',
      compatProfileSource: 'persisted',
      compatProfilePromotedFrom: sourceProfile,
      compatProfileResetReason: 'runtime-crash-fallback'
    })

    sessionOverride = {
      profile: 'safe-fallback',
      source: 'session-override',
      persistEligible: true
    }

    appendEarlyCrashLog('windows.compat.runtime-fallback', 'windows compatibility forced safe fallback after runtime crash', {
      compatProfile: sourceProfile,
      nextCompatProfile: 'safe-fallback',
      compatProfileSource: currentLaunchContext?.source || lastEffectiveConfig?.source || 'default',
      reason: crashState.reason,
      exitCode: crashState.exitCode
    })

    return getSnapshot()
  }

  async function setSessionOverrideProfile(
    profile,
    { source = 'session-override', resetPersisted = false, resetReason = '', persistEligible = false } = {}
  ) {
    const normalizedProfile = normalizeWindowsCompatProfile(profile)
    sessionOverride = {
      profile: normalizedProfile,
      source,
      persistEligible: Boolean(persistEligible)
    }

    if (resetPersisted) {
      await clearPersistedState(resetReason || 'manual-reset')
    }

    appendEarlyCrashLog('windows.compat.session-override', 'windows compatibility session override updated', {
      compatProfile: normalizedProfile,
      compatProfileSource: source,
      compatProfileResetReason: resetReason || ''
    })

    return getSnapshot()
  }

  function clearSessionOverride() {
    sessionOverride = null
  }

  function getRetryTargetProfile() {
    const currentProfile = normalizeWindowsCompatProfile(lastEffectiveConfig?.profile || persistedState.profile || 'standard')
    if (currentProfile !== 'safe-fallback') return currentProfile
    const lastCrashProfile = normalizeWindowsCompatProfile(persistedState.lastCrash?.profile || 'standard')
    return lastCrashProfile === 'safe-fallback' ? 'standard' : lastCrashProfile
  }

  function getSnapshot() {
    const effectiveConfig = buildEffectiveLaunchConfig()
    return {
      supported,
      stateFilePath,
      compatProfile: effectiveConfig.profile,
      compatProfileSource: effectiveConfig.source,
      persistedProfile: normalizeWindowsCompatProfile(persistedState.profile),
      stableLaunchCount: Math.max(0, Math.trunc(toFiniteNumber(persistedState.stableLaunchCount, 0))),
      lastCrash: normalizeCrashState(persistedState.lastCrash),
      rendererSandboxDisabled: effectiveConfig.rendererSandboxDisabled,
      rendererCodeIntegrityDisabled: effectiveConfig.disableRendererCodeIntegrity,
      useSafeFallback: effectiveConfig.useSafeFallback,
      retryTargetProfile: getRetryTargetProfile(),
      compatProfileResetReason: String(persistedState.compatProfileResetReason || '').trim()
    }
  }

  return {
    WINDOWS_COMPAT_PROFILE_ORDER,
    beginProfileLaunchContext,
    beginWindowLaunchContext,
    clearPersistedState,
    clearSessionOverride,
    getNextWindowsCompatProfile,
    getPreviousWindowsCompatProfile,
    getRetryTargetProfile,
    getSnapshot,
    isSupported: () => supported,
    enterSafeFallback,
    markMainUiLoaded,
    reportRendererStable,
    markNormalExit,
    normalizeWindowsCompatProfile,
    recordCrashAndResolveNextProfile,
    setSessionOverrideProfile,
    stateFilePath
  }
}

module.exports = {
  WINDOWS_COMPAT_PROFILE_ORDER,
  createWindowsCompatController,
  getNextWindowsCompatProfile,
  getPreviousWindowsCompatProfile,
  normalizeWindowsCompatProfile
}
