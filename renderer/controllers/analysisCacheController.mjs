function normalizeAnalysisMode(mode) {
  return String(mode || '').trim().toLowerCase() === 'segmented' ? 'segmented' : 'full'
}

export function createAnalysisCacheController({
  electronAPI,
  dom,
  analysisCacheSchemaVersion,
  formatBytes,
  formatCount,
  showToast,
  buildComparisonSignature,
  computeTextFingerprint,
  getCurrentCorpusMode,
  getCurrentCorpusId,
  getCurrentSelectedCorpora,
  getCurrentComparisonEntries,
  getCurrentAnalysisSnapshot,
  getCurrentCacheKey,
  getCurrentCachePayload,
  setCurrentCachePayload
}) {
  const {
    analysisCacheValue,
    analysisCacheStatusText,
    refreshAnalysisCacheButton,
    clearAnalysisCacheButton,
    rebuildAnalysisCacheButton
  } = dom

  function buildAnalysisCacheKey(result = {}, text = '') {
    const mode = String(result?.mode || getCurrentCorpusMode() || 'quick').trim() || 'quick'
    const corpusId = String(result?.corpusId || getCurrentCorpusId() || '').trim()
    const filePath = String(result?.filePath || '').trim()
    const selectedIds = Array.isArray(result?.selectedItems)
      ? result.selectedItems.map(item => String(item?.id || '').trim()).filter(Boolean).join(',')
      : getCurrentSelectedCorpora().map(item => String(item?.id || '').trim()).filter(Boolean).join(',')
    const comparisonSignature = buildComparisonSignature(
      Array.isArray(result?.comparisonEntries) ? result.comparisonEntries : getCurrentComparisonEntries()
    )
    const identity = [mode, corpusId, selectedIds, filePath, comparisonSignature].join('|')
    return `wordz-v1:${computeTextFingerprint(identity)}:${computeTextFingerprint(text)}`
  }

  function normalizeCachedStats(stats) {
    if (!stats || typeof stats !== 'object') return null
    if (!Array.isArray(stats.freqRows)) return null
    return {
      freqRows: stats.freqRows,
      tokenCount: Number(stats.tokenCount) || 0,
      typeCount: Number(stats.typeCount) || 0,
      ttr: Number(stats.ttr) || 0,
      sttr: Number(stats.sttr) || 0,
      compareSignature: String(stats.compareSignature || ''),
      compareCorpora: Array.isArray(stats.compareCorpora) ? stats.compareCorpora : [],
      compareRows: Array.isArray(stats.compareRows) ? stats.compareRows : []
    }
  }

  function normalizeAnalysisCachePayload(payload) {
    if (!payload || typeof payload !== 'object') return null
    if (Number(payload.schemaVersion) !== analysisCacheSchemaVersion) return null
    const analysisMode = normalizeAnalysisMode(payload.analysisMode)
    const rawCorpusData = payload.corpusData
    if (!rawCorpusData || typeof rawCorpusData !== 'object') return null
    const corpusData = {
      sentences: Array.isArray(rawCorpusData.sentences) ? rawCorpusData.sentences : [],
      tokenObjects: Array.isArray(rawCorpusData.tokenObjects) ? rawCorpusData.tokenObjects : [],
      tokens: Array.isArray(rawCorpusData.tokens) ? rawCorpusData.tokens : []
    }
    if (
      analysisMode === 'full' &&
      (!Array.isArray(rawCorpusData.sentences) || !Array.isArray(rawCorpusData.tokenObjects) || !Array.isArray(rawCorpusData.tokens))
    ) {
      return null
    }
    const normalizedNgrams = {}
    if (payload.ngrams && typeof payload.ngrams === 'object') {
      for (const [rawSize, rows] of Object.entries(payload.ngrams)) {
        if (!Array.isArray(rows)) continue
        const size = Number(rawSize)
        if (!Number.isFinite(size) || size <= 0) continue
        normalizedNgrams[String(size)] = rows
      }
    }
    return {
      schemaVersion: analysisCacheSchemaVersion,
      analysisMode,
      corpusData,
      stats: normalizeCachedStats(payload.stats),
      ngrams: normalizedNgrams
    }
  }

  async function loadAnalysisCachePayload(cacheKey) {
    const normalizedKey = String(cacheKey || '').trim()
    if (!normalizedKey || !electronAPI?.getAnalysisCache) return null
    try {
      const result = await electronAPI.getAnalysisCache(normalizedKey)
      if (!result?.success || !result?.hit) return null
      return normalizeAnalysisCachePayload(result.payload)
    } catch (error) {
      console.warn('[analysis-cache.load]', error)
      return null
    }
  }

  async function persistAnalysisCachePayload(cacheKey = getCurrentCacheKey(), payload = getCurrentCachePayload()) {
    const normalizedKey = String(cacheKey || '').trim()
    const normalizedPayload = normalizeAnalysisCachePayload(payload)
    if (!normalizedKey || !normalizedPayload || !electronAPI?.setAnalysisCache) return false
    try {
      const result = await electronAPI.setAnalysisCache(normalizedKey, normalizedPayload)
      return result?.success === true
    } catch (error) {
      console.warn('[analysis-cache.save]', error)
      return false
    }
  }

  function updateCurrentAnalysisCache({ stats = null, ngramSize = null, ngramRows = null } = {}) {
    const currentPayload = getCurrentCachePayload()
    if (!currentPayload || typeof currentPayload !== 'object') return

    let nextPayload = currentPayload

    if (stats && typeof stats === 'object') {
      nextPayload = {
        ...nextPayload,
        stats: {
          freqRows: Array.isArray(stats.freqRows) ? stats.freqRows : [],
          tokenCount: Number(stats.tokenCount) || 0,
          typeCount: Number(stats.typeCount) || 0,
          ttr: Number(stats.ttr) || 0,
          sttr: Number(stats.sttr) || 0,
          compareSignature: String(stats.compareSignature || ''),
          compareCorpora: Array.isArray(stats.compareCorpora) ? stats.compareCorpora : [],
          compareRows: Array.isArray(stats.compareRows) ? stats.compareRows : []
        }
      }
    }

    if (Number.isFinite(Number(ngramSize)) && Array.isArray(ngramRows)) {
      nextPayload = {
        ...nextPayload,
        ngrams: {
          ...(nextPayload.ngrams || {}),
          [String(Number(ngramSize))]: ngramRows
        }
      }
    }

    setCurrentCachePayload(nextPayload)
  }

  function buildAnalysisCachePayloadFromCurrentState() {
    const currentPayload = getCurrentCachePayload()
    const snapshot = getCurrentAnalysisSnapshot()
    const existingNgrams =
      currentPayload && typeof currentPayload === 'object' && currentPayload.ngrams
        ? currentPayload.ngrams
        : {}
    const hasStats = snapshot.freqRows.length > 0 || snapshot.tokenCount > 0

    return normalizeAnalysisCachePayload({
      schemaVersion: analysisCacheSchemaVersion,
      analysisMode: snapshot.analysisMode,
      corpusData:
        snapshot.analysisMode === 'segmented'
          ? { sentences: [], tokenObjects: [], tokens: [] }
          : {
              sentences: Array.isArray(snapshot.sentenceObjects) ? snapshot.sentenceObjects : [],
              tokenObjects: Array.isArray(snapshot.tokenObjects) ? snapshot.tokenObjects : [],
              tokens: Array.isArray(snapshot.tokens) ? snapshot.tokens : []
            },
      stats: hasStats
        ? {
            freqRows: snapshot.freqRows,
            tokenCount: snapshot.tokenCount,
            typeCount: snapshot.typeCount,
            ttr: snapshot.ttr,
            sttr: snapshot.sttr,
            compareSignature: buildComparisonSignature(snapshot.comparisonEntries),
            compareCorpora: snapshot.comparisonCorpora,
            compareRows: snapshot.comparisonRows
          }
        : null,
      ngrams: existingNgrams
    })
  }

  async function refreshAnalysisCacheState({ silent = false } = {}) {
    if (!analysisCacheValue || !analysisCacheStatusText) return null
    if (!electronAPI?.getAnalysisCacheState) {
      analysisCacheValue.textContent = '不可用'
      analysisCacheStatusText.textContent = '当前版本未启用分析缓存状态接口。'
      if (refreshAnalysisCacheButton) refreshAnalysisCacheButton.disabled = true
      if (clearAnalysisCacheButton) clearAnalysisCacheButton.disabled = true
      if (rebuildAnalysisCacheButton) rebuildAnalysisCacheButton.disabled = true
      return null
    }

    try {
      const state = await electronAPI.getAnalysisCacheState()
      if (!state?.success) {
        analysisCacheValue.textContent = '读取失败'
        analysisCacheStatusText.textContent = state?.message || '分析缓存状态读取失败。'
        return null
      }
      const entryCount = Number(state.entryCount) || 0
      analysisCacheValue.textContent = `${formatCount(entryCount)} 条`
      analysisCacheStatusText.textContent = `目录：${state.cacheDir || '未知'} ｜ 总占用：${formatBytes(state.totalBytes)} ｜ 上限：${formatBytes(state.maxTotalBytes)}`
      if (clearAnalysisCacheButton) clearAnalysisCacheButton.disabled = entryCount === 0
      if (rebuildAnalysisCacheButton) rebuildAnalysisCacheButton.disabled = !getCurrentCacheKey()
      return state
    } catch (error) {
      console.warn('[analysis-cache.state]', error)
      analysisCacheValue.textContent = '读取失败'
      analysisCacheStatusText.textContent = error?.message || '分析缓存状态读取失败。'
      if (!silent) {
        showToast('分析缓存状态读取失败。', {
          title: '缓存管理'
        })
      }
      return null
    }
  }

  async function rebuildCurrentAnalysisCache({ silent = false } = {}) {
    const cacheKey = String(getCurrentCacheKey() || '').trim()
    if (!cacheKey) {
      if (!silent) {
        showToast('当前没有可重建缓存的语料。', {
          title: '缓存管理'
        })
      }
      return false
    }

    const nextPayload = buildAnalysisCachePayloadFromCurrentState()
    if (!nextPayload) {
      if (!silent) {
        showToast('当前缓存快照无效，无法重建。', {
          title: '缓存管理'
        })
      }
      return false
    }

    setCurrentCachePayload(nextPayload)
    const saved = await persistAnalysisCachePayload(cacheKey, nextPayload)
    if (!saved) {
      if (!silent) {
        showToast('重建分析缓存失败。', {
          title: '缓存管理'
        })
      }
      return false
    }

    if (electronAPI?.pruneAnalysisCache) {
      try {
        await electronAPI.pruneAnalysisCache()
      } catch {
        // ignore prune failures
      }
    }

    await refreshAnalysisCacheState({ silent: true })
    if (!silent) {
      showToast('已重建当前语料缓存。', {
        title: '缓存管理',
        type: 'success'
      })
    }
    return true
  }

  return {
    buildAnalysisCacheKey,
    loadAnalysisCachePayload,
    normalizeAnalysisCachePayload,
    normalizeCachedStats,
    persistAnalysisCachePayload,
    rebuildCurrentAnalysisCache,
    refreshAnalysisCacheState,
    updateCurrentAnalysisCache
  }
}
