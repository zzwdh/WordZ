import {
  buildAllCollocateRows as buildAllCollocateRowsData,
  buildCollocateRows as buildCollocateRowsData
} from '../features/collocate.mjs'
import {
  buildAllCompareRows as buildAllCompareRowsData,
  buildCompareRows as buildCompareRowsData
} from '../features/compare.mjs'
import { buildLocatorRows as buildLocatorRowsData } from '../features/locator.mjs'
import {
  buildAllKWICRows as buildAllKWICRowsData,
  buildKWICRows as buildKWICRowsData
} from '../features/kwic.mjs'
import {
  buildAllNgramRows as buildAllNgramRowsData,
  buildNgramRows as buildNgramRowsData
} from '../features/ngram.mjs'
import {
  buildAllFrequencyRows as buildAllFrequencyRowsData,
  buildFrequencyRows as buildFrequencyRowsData,
  buildStatsRows as buildStatsRowsData
} from '../features/stats.mjs'
import { saveTableFile } from '../utils.mjs'

export function createTableActionsController({
  dom,
  exportFeedback,
  sortKWICResults,
  getStatsState,
  getNgramState,
  getCompareState,
  getKWICState,
  getCollocateState,
  getLocatorState,
  getCurrentNgramSize,
  setCurrentKWICSortCache
}) {
  const {
    copyStatsButton,
    copyFreqButton,
    exportAllFreqButton,
    exportNgramButton,
    exportAllNgramButton,
    copyCompareButton,
    exportAllCompareButton,
    copyKWICButton,
    exportAllKWICButton,
    exportCollocateButton,
    exportAllCollocateButton,
    copyLocatorButton
  } = dom

  function buildStatsRows() {
    return buildStatsRowsData(getStatsState())
  }

  function buildFrequencyRows() {
    return buildFrequencyRowsData(getStatsState())
  }

  function buildAllFrequencyRows() {
    return buildAllFrequencyRowsData(getStatsState())
  }

  function buildNgramRows() {
    return buildNgramRowsData(getNgramState())
  }

  function buildAllNgramRows() {
    return buildAllNgramRowsData(getNgramState())
  }

  function buildCompareRows() {
    return buildCompareRowsData(getCompareState())
  }

  function buildAllCompareRows() {
    return buildAllCompareRowsData(getCompareState())
  }

  function buildKWICRows() {
    const result = buildKWICRowsData(getKWICState(), sortKWICResults)
    setCurrentKWICSortCache(result.cache)
    return result.rows
  }

  function buildAllKWICRows() {
    const result = buildAllKWICRowsData(getKWICState(), sortKWICResults)
    setCurrentKWICSortCache(result.cache)
    return result.rows
  }

  function buildCollocateRows() {
    return buildCollocateRowsData(getCollocateState())
  }

  function buildAllCollocateRows() {
    return buildAllCollocateRowsData(getCollocateState())
  }

  function buildLocatorRows() {
    return buildLocatorRowsData(getLocatorState())
  }

  function bindTableActionEvents() {
    copyStatsButton?.addEventListener('click', async () => {
      await saveTableFile('统计摘要', buildStatsRows(), exportFeedback)
    })

    copyFreqButton?.addEventListener('click', async () => {
      await saveTableFile('词频表_当前页', buildFrequencyRows(), exportFeedback)
    })

    exportAllFreqButton?.addEventListener('click', async () => {
      await saveTableFile('词频表_全部', buildAllFrequencyRows(), exportFeedback)
    })

    exportNgramButton?.addEventListener('click', async () => {
      await saveTableFile(`Ngram_${getCurrentNgramSize()}gram_当前页`, buildNgramRows(), exportFeedback)
    })

    exportAllNgramButton?.addEventListener('click', async () => {
      await saveTableFile(`Ngram_${getCurrentNgramSize()}gram_全部`, buildAllNgramRows(), exportFeedback)
    })

    copyCompareButton?.addEventListener('click', async () => {
      await saveTableFile('多语料对比_当前页', buildCompareRows(), exportFeedback)
    })

    exportAllCompareButton?.addEventListener('click', async () => {
      await saveTableFile('多语料对比_全部', buildAllCompareRows(), exportFeedback)
    })

    copyKWICButton?.addEventListener('click', async () => {
      await saveTableFile('KWIC_当前页', buildKWICRows(), exportFeedback)
    })

    exportAllKWICButton?.addEventListener('click', async () => {
      await saveTableFile('KWIC_全部', buildAllKWICRows(), exportFeedback)
    })

    exportCollocateButton?.addEventListener('click', async () => {
      await saveTableFile('Collocate_当前页', buildCollocateRows(), exportFeedback)
    })

    exportAllCollocateButton?.addEventListener('click', async () => {
      await saveTableFile('Collocate_全部', buildAllCollocateRows(), exportFeedback)
    })

    copyLocatorButton?.addEventListener('click', async () => {
      await saveTableFile('原文定位表', buildLocatorRows(), exportFeedback)
    })
  }

  return {
    bindTableActionEvents
  }
}
