function createSmokeBridge({
  ipcClient,
  clampSmokeDelayMs,
  normalizeTextInput,
  processEnv = process.env
}) {
  return {
    getSmokeObserverState: () =>
      ipcClient.invoke('get-smoke-observer-state'),

    getPackagedSmokeConfig: () =>
      ipcClient.invoke('get-packaged-smoke-config'),

    reportPackagedSmokeResult: ({ status, stage, message, corpusName, statsRowCount, kwicResultCount, runtime } = {}) =>
      ipcClient.invoke('report-packaged-smoke-result', {
        status: normalizeTextInput(status, 24),
        stage: normalizeTextInput(stage, 80),
        message: normalizeTextInput(message, 600),
        corpusName: normalizeTextInput(corpusName, 160),
        statsRowCount: Number(statsRowCount),
        kwicResultCount: Number(kwicResultCount),
        runtime: runtime && typeof runtime === 'object'
          ? {
              analysisMode: normalizeTextInput(runtime.analysisMode, 24),
              searchQuery: normalizeTextInput(runtime.searchQuery, 160)
            }
          : null
      }),

    getSmokeAnalysisDelayMs: () =>
      clampSmokeDelayMs(processEnv.CORPUS_LITE_SMOKE_ANALYSIS_DELAY_MS)
  }
}

module.exports = {
  createSmokeBridge
}
