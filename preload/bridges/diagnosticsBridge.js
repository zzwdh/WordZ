function createDiagnosticsBridge({
  ipcClient,
  normalizeBoolean,
  normalizeTextInput
}) {
  return {
    getDiagnosticState: () =>
      ipcClient.invoke('get-diagnostic-state'),

    setDiagnosticLoggingEnabled: enabled =>
      ipcClient.invoke('set-diagnostic-logging-enabled', normalizeBoolean(enabled)),

    writeDiagnosticLog: ({ level, scope, message, details } = {}) =>
      ipcClient.invoke('write-diagnostic-log', {
        level: normalizeTextInput(level, 16),
        scope: normalizeTextInput(scope, 80),
        message: normalizeTextInput(message, 600),
        details: details ?? null
      }),

    exportDiagnosticReport: rendererState =>
      ipcClient.invoke('export-diagnostic-report', rendererState ?? {}),

    exportDiagnosticReportAuto: rendererState =>
      ipcClient.invoke('export-diagnostic-report-auto', rendererState ?? {}),

    openGitHubFeedback: ({ issueTitle, rendererState } = {}) =>
      ipcClient.invoke('open-github-feedback', {
        issueTitle: normalizeTextInput(issueTitle, 120),
        rendererState: rendererState ?? {}
      }),

    getAnalysisCache: cacheKey =>
      ipcClient.invoke('analysis-cache-get', {
        cacheKey: normalizeTextInput(cacheKey, 320)
      }),

    setAnalysisCache: (cacheKey, entry) =>
      ipcClient.invoke('analysis-cache-set', {
        cacheKey: normalizeTextInput(cacheKey, 320),
        entry: entry ?? null
      }),

    deleteAnalysisCache: cacheKey =>
      ipcClient.invoke('analysis-cache-delete', {
        cacheKey: normalizeTextInput(cacheKey, 320)
      }),

    clearAnalysisCache: () =>
      ipcClient.invoke('analysis-cache-clear'),

    getAnalysisCacheState: () =>
      ipcClient.invoke('analysis-cache-state'),

    pruneAnalysisCache: () =>
      ipcClient.invoke('analysis-cache-prune'),

    openExternalUrl: url =>
      ipcClient.invoke('open-external-url', normalizeTextInput(url, 4096)),

    showPathInFolder: targetPath =>
      ipcClient.invoke('show-path-in-folder', normalizeTextInput(targetPath, 4096)),

    consumeCrashRecoveryState: () =>
      ipcClient.invoke('consume-crash-recovery-state')
  }
}

module.exports = {
  createDiagnosticsBridge
}
