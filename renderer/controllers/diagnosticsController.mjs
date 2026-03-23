const AUTO_BUG_FEEDBACK_COOLDOWN_MS = 45 * 1000
const AUTO_BUG_FEEDBACK_MAX_PROMPTS = 3

function normalizeDiagnosticError(error) {
  return error instanceof Error
    ? {
        name: error.name,
        message: error.message,
        stack: error.stack || ''
      }
    : {
        name: 'Error',
        message: String(error || '未知错误')
      }
}

function shouldSkipAutoBugFeedback(normalizedError) {
  if (!normalizedError || !normalizedError.message) return true
  const name = String(normalizedError.name || '').toLowerCase()
  if (name === 'aborterror') return true

  const message = String(normalizedError.message).toLowerCase()
  return (
    message.includes('aborted') ||
    message.includes('cancelled') ||
    message.includes('用户取消') ||
    message.includes('operation was aborted')
  )
}

function buildAutoBugIssueTitle(scope, normalizedError) {
  const scopeText = String(scope || 'renderer').trim() || 'renderer'
  const messageText = String(normalizedError?.message || 'Unknown error').trim() || 'Unknown error'
  return `[Bug][Auto] ${scopeText}: ${messageText}`.slice(0, 120)
}

export function createDiagnosticsController({
  dom,
  electronAPI,
  getCurrentUISettings,
  getDiagnosticRendererState,
  showMissingBridge,
  showAlert,
  showConfirm,
  showToast,
  notifySystem,
  setWindowProgressState
}) {
  const {
    diagnosticsStatusText,
    exportDiagnosticsButton,
    reportIssueButton
  } = dom

  let autoBugFeedbackPromptCount = 0
  let autoBugFeedbackLastPromptAt = 0
  let autoBugFeedbackLastSignature = ''
  let autoBugFeedbackInFlight = false

  async function recordDiagnostic(level, scope, message, details = null) {
    if (!electronAPI?.writeDiagnosticLog) return
    try {
      await electronAPI.writeDiagnosticLog({
        level,
        scope,
        message,
        details
      })
    } catch (error) {
      console.warn('[diagnostics.log]', error)
    }
  }

  function recordDiagnosticError(scope, error, details = null) {
    const normalizedError = normalizeDiagnosticError(error)
    void recordDiagnostic('error', scope, normalizedError.message, {
      ...(details && typeof details === 'object' ? details : {}),
      error: normalizedError
    })
    return normalizedError
  }

  async function exportDiagnosticsForFeedback(rendererState) {
    if (!electronAPI?.exportDiagnosticReportAuto) {
      return {
        success: false,
        unsupported: true,
        message: '当前版本不支持自动导出诊断包。'
      }
    }
    try {
      const result = await electronAPI.exportDiagnosticReportAuto(rendererState)
      if (!result?.success || !result.filePath) {
        return {
          success: false,
          message: result?.message || '自动导出诊断包失败。'
        }
      }
      return {
        success: true,
        filePath: result.filePath
      }
    } catch (error) {
      return {
        success: false,
        message: error?.message || '自动导出诊断包失败。'
      }
    }
  }

  async function refreshDiagnosticsStatusText() {
    if (!diagnosticsStatusText) return
    const enabled = getCurrentUISettings().debugLogging === true
    const fallbackText = enabled
      ? '调试日志已开启，会记录当前会话的关键操作和错误。'
      : '默认仅保留轻量错误摘要。开启后会把当前会话的关键操作和错误写入诊断日志，便于导出或反馈到 GitHub。'

    if (!electronAPI?.getDiagnosticState) {
      diagnosticsStatusText.textContent = fallbackText
      return
    }

    try {
      const result = await electronAPI.getDiagnosticState()
      const diagnostics = result?.success ? result.diagnostics : null
      if (!diagnostics) {
        diagnosticsStatusText.textContent = fallbackText
        return
      }
      const errorCount = Array.isArray(diagnostics.recentErrors) ? diagnostics.recentErrors.length : 0
      const logStatus = diagnostics.debugLoggingEnabled ? '已开启' : '未开启'
      diagnosticsStatusText.textContent = `本次会话 ${diagnostics.sessionId || ''} ｜ 调试日志${logStatus} ｜ 最近错误 ${errorCount} 条${diagnostics.logFilePath ? ` ｜ 日志：${diagnostics.logFilePath}` : ''}`
    } catch (error) {
      console.warn('[diagnostics.state]', error)
      diagnosticsStatusText.textContent = fallbackText
    }
  }

  async function openGitHubFeedbackIssue({
    issueTitle = '[Bug] 请简要描述问题',
    source = 'manual',
    successTitle = '反馈已准备',
    successMessage = '已打开 GitHub Issues，新页面里已预填当前会话摘要。',
    failureTitle = '打开 GitHub 反馈失败',
    failureMessage = '暂时无法打开 GitHub 反馈页。',
    autoExportDiagnostics = false,
    diagnosticsDetails = null
  } = {}) {
    if (!electronAPI?.openGitHubFeedback) {
      await showMissingBridge('openGitHubFeedback')
      return false
    }

    const rendererState = getDiagnosticRendererState()
    let diagnosticsExportPath = ''
    if (autoExportDiagnostics) {
      const exportResult = await exportDiagnosticsForFeedback(rendererState)
      if (exportResult.success) {
        diagnosticsExportPath = exportResult.filePath
        rendererState.autoDiagnosticReportPath = diagnosticsExportPath
      } else if (!exportResult.unsupported) {
        void recordDiagnostic('warn', 'diagnostics.auto-export', exportResult.message || '自动导出诊断包失败。', {
          source
        })
      }
    }

    const result = await electronAPI.openGitHubFeedback({
      issueTitle,
      rendererState
    })

    if (!result || !result.success) {
      await showAlert({
        title: failureTitle,
        message: result?.message || failureMessage
      })
      return false
    }

    await refreshDiagnosticsStatusText()
    void recordDiagnostic('info', 'diagnostics', '用户已打开 GitHub 反馈页。', {
      source,
      issueUrl: result.issueUrl,
      ...(diagnosticsExportPath ? { diagnosticsExportPath } : {}),
      ...(diagnosticsDetails && typeof diagnosticsDetails === 'object' ? diagnosticsDetails : {})
    })
    showToast(successMessage, {
      title: successTitle,
      type: 'success',
      duration: 2600
    })
    return true
  }

  async function maybePromptAutoBugFeedback(scope, normalizedError, details = null) {
    if (shouldSkipAutoBugFeedback(normalizedError)) return
    if (!electronAPI?.openGitHubFeedback) return
    if (autoBugFeedbackInFlight) return
    if (autoBugFeedbackPromptCount >= AUTO_BUG_FEEDBACK_MAX_PROMPTS) return

    const signature = `${scope}:${normalizedError.name}:${normalizedError.message}`.slice(0, 320)
    const now = Date.now()
    if (
      signature === autoBugFeedbackLastSignature &&
      now - autoBugFeedbackLastPromptAt < AUTO_BUG_FEEDBACK_COOLDOWN_MS
    ) {
      return
    }

    autoBugFeedbackInFlight = true
    try {
      const confirmed = await showConfirm({
        title: '检测到异常',
        message: `WordZ 捕获到一个异常：${normalizedError.message}\n\n是否立即打开 GitHub 反馈页？系统会自动附带当前会话诊断信息。`,
        confirmText: '立即反馈',
        cancelText: '稍后',
        danger: true
      })

      autoBugFeedbackLastSignature = signature
      autoBugFeedbackLastPromptAt = Date.now()

      if (!confirmed) return

      autoBugFeedbackPromptCount += 1
      await openGitHubFeedbackIssue({
        issueTitle: buildAutoBugIssueTitle(scope, normalizedError),
        source: 'auto-error-capture',
        successTitle: '反馈页已打开',
        successMessage: '已打开 GitHub Issues，并自动附带异常上下文与诊断包路径。',
        autoExportDiagnostics: true,
        diagnosticsDetails: {
          scope,
          autoCaptured: true,
          error: normalizedError,
          details: details ?? null
        }
      })
    } finally {
      autoBugFeedbackInFlight = false
    }
  }

  function bindDiagnosticsEvents() {
    exportDiagnosticsButton?.addEventListener('click', async () => {
      if (!electronAPI?.exportDiagnosticReport) {
        await showMissingBridge('exportDiagnosticReport')
        return
      }

      void setWindowProgressState({
        source: 'diagnostics-export',
        state: 'indeterminate',
        priority: 30
      })
      const result = await electronAPI.exportDiagnosticReport(getDiagnosticRendererState())
      if (!result || !result.success) {
        void setWindowProgressState({
          source: 'diagnostics-export',
          state: 'none'
        })
        if (result?.canceled) {
          showToast('已取消导出诊断报告。', {
            title: '未导出'
          })
          return
        }
        await showAlert({
          title: '导出诊断报告失败',
          message: result?.message || '诊断报告导出失败，请稍后重试。'
        })
        return
      }

      await refreshDiagnosticsStatusText()
      void recordDiagnostic('info', 'diagnostics', '用户已导出诊断报告。', { filePath: result.filePath })
      showToast(`诊断报告已导出到：${result.filePath}`, {
        title: '导出完成',
        type: 'success',
        duration: 2600
      })
      void setWindowProgressState({
        source: 'diagnostics-export',
        state: 'none'
      })
      void notifySystem({
        title: '诊断报告已导出',
        body: result.filePath,
        tag: 'diagnostics-export',
        category: 'diagnostics-export',
        action: {
          actionId: 'reveal-path',
          payload: { path: result.filePath }
        }
      })
    })

    reportIssueButton?.addEventListener('click', async () => {
      await openGitHubFeedbackIssue({
        issueTitle: '[Bug] 请简要描述问题',
        source: 'manual',
        autoExportDiagnostics: true,
        successMessage: '已打开 GitHub Issues，并自动附带当前会话诊断包路径。'
      })
    })
  }

  return {
    bindDiagnosticsEvents,
    maybePromptAutoBugFeedback,
    openGitHubFeedbackIssue,
    recordDiagnostic,
    recordDiagnosticError,
    refreshDiagnosticsStatusText
  }
}
