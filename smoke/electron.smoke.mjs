import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { createRequire } from 'node:module'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { _electron as electron } from 'playwright-core'

const require = createRequire(import.meta.url)
const electronExecutablePath = require('electron')
const ExcelJS = require('exceljs')
const iconv = require('iconv-lite')
const packageManifest = require(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'package.json'))
const { buildSimplePdfBuffer } = require(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'support', 'pdfFixture.js'))
const __dirname = path.dirname(fileURLToPath(import.meta.url))
const appRoot = path.resolve(__dirname, '..')
const APP_NAME = packageManifest.productName || packageManifest.name || 'WordZ'
const APP_VERSION = packageManifest.version || ''
const DOCX_FIXTURE_BASE64 = 'UEsDBBQAAAAIAEcMdFzXeYTq8QAAALgBAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbH2QzU7DMBCE730Ky9cqccoBIZSkB36OwKE8wMreJFb9J69b2rdn00KREOVozXwz62nXB+/EHjPZGDq5qhspMOhobBg7+b55ru6koALBgIsBO3lEkut+0W6OCUkwHKiTUynpXinSE3qgOiYMrAwxeyj8zKNKoLcworppmlulYygYSlXmDNkvhGgfcYCdK+LpwMr5loyOpHg4e+e6TkJKzmoorKt9ML+Kqq+SmsmThyabaMkGqa6VzOL1jh/0lSfK1qB4g1xewLNRfcRslIl65xmu/0/649o4DFbjhZ/TUo4aiXh77+qL4sGG71+06jR8/wlQSwMEFAAAAAgARwx0XCAbhuqyAAAALgEAAAsAAABfcmVscy8ucmVsc43Puw6CMBQG4J2naM4uBQdjDIXFmLAafICmPZRGeklbL7y9HRzEODie23fyN93TzOSOIWpnGdRlBQStcFJbxeAynDZ7IDFxK/nsLDJYMELXFs0ZZ57yTZy0jyQjNjKYUvIHSqOY0PBYOo82T0YXDE+5DIp6Lq5cId1W1Y6GTwPagpAVS3rJIPSyBjIsHv/h3ThqgUcnbgZt+vHlayPLPChMDB4uSCrf7TKzQHNKuorZvgBQSwMEFAAAAAgARwx0XHOTwqW5AAAAJwEAABEAAAB3b3JkL2RvY3VtZW50LnhtbG1PMW7DMAzc8wpCeyM3Q1AYtrLlBc0DZIu1DVikQKp18/tITrtlOdzxcEeyu/zGFX5QdGHqzfuxMYA0clho6s3t8/r2YUCzp+BXJuzNHdVc3KHb2sDjd0TKUBpI2603c86ptVbHGaPXIyek4n2xRJ+LlMluLCEJj6haFsTVnprmbKNfyLgDQGkdONwr3UVyBaRCdsKKMKzMEQZZpjlDnXS2ehVlx/Qy+xd4pvciwfAyWsnzhMr+X3QPUEsBAhQDFAAAAAgARwx0XNd5hOrxAAAAuAEAABMAAAAAAAAAAAAAAIABAAAAAFtDb250ZW50X1R5cGVzXS54bWxQSwECFAMUAAAACABHDHRcIBuG6rIAAAAuAQAACwAAAAAAAAAAAAAAgAEiAQAAX3JlbHMvLnJlbHNQSwECFAMUAAAACABHDHRcc5PCpbkAAAAnAQAAEQAAAAAAAAAAAAAAgAH9AQAAd29yZC9kb2N1bWVudC54bWxQSwUGAAAAAAMAAwC5AAAA5QIAAAAA'

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

async function launchSmokeElectronApp(options = {}) {
  return electron.launch({
    executablePath: electronExecutablePath,
    ...options
  })
}

async function isVisible(page, selector) {
  return page.locator(selector).evaluate(node => !node.classList.contains('hidden'))
}

async function waitForVisible(page, selector) {
  await page.waitForFunction(targetSelector => {
    const node = document.querySelector(targetSelector)
    return Boolean(node) && !node.classList.contains('hidden')
  }, selector)
}

async function waitForHidden(page, selector) {
  await page.waitForFunction(targetSelector => {
    const node = document.querySelector(targetSelector)
    return Boolean(node) && node.classList.contains('hidden')
  }, selector)
}

async function dismissWelcomeOverlayIfVisible(page, { restorePrompt = 'skip' } = {}) {
  const isOverlayVisible = await isVisible(page, '#welcomeOverlay')
  if (!isOverlayVisible) return

  await page.waitForFunction(() => {
    const overlay = document.getElementById('welcomeOverlay')
    const button = document.getElementById('closeWelcomeButton')
    const restorePromptNode = document.getElementById('welcomeRestorePrompt')
    return Boolean(overlay) &&
      !overlay.classList.contains('hidden') &&
      (
        (Boolean(button) && !button.disabled) ||
        (Boolean(restorePromptNode) && !restorePromptNode.classList.contains('hidden'))
      )
  })

  const restorePromptVisible = await isVisible(page, '#welcomeRestorePrompt').catch(() => false)
  if (restorePromptVisible) {
    await page.locator(restorePrompt === 'restore' ? '#restoreWorkspaceButton' : '#skipWorkspaceRestoreButton').click()
  }

  await page.waitForFunction(() => {
    const overlay = document.getElementById('welcomeOverlay')
    const button = document.getElementById('closeWelcomeButton')
    return Boolean(overlay) &&
      !overlay.classList.contains('hidden') &&
      Boolean(button) &&
      !button.disabled
  })
  await page.locator('#closeWelcomeButton').scrollIntoViewIfNeeded()
  await page.locator('#closeWelcomeButton').click()
  await waitForHidden(page, '#welcomeOverlay')
}

async function prepareWindow(page, options = {}) {
  await page.waitForLoadState('domcontentloaded')
  await dismissWelcomeOverlayIfVisible(page, options)
  await page.evaluate(() => {
    const overflow = document.querySelector('.toolbar-native-overflow')
    if (overflow) {
      overflow.classList.remove('hidden')
      overflow.setAttribute('aria-hidden', 'false')
      overflow.style.setProperty('display', 'flex', 'important')
      overflow.style.setProperty('gap', '8px')
      overflow.style.setProperty('align-items', 'center')
      overflow.style.setProperty('padding', '0 20px')
    }
  })
}

async function chooseCorpusMenuAction(page, actionSelector) {
  await page.locator('#openCorpusMenuButton').click({ force: true }).catch(() => {})
  const panelVisible = await isVisible(page, '#openCorpusMenuPanel').catch(() => false)
  if (!panelVisible) {
    await page.evaluate(() => {
      const panel = document.getElementById('openCorpusMenuPanel')
      const button = document.getElementById('openCorpusMenuButton')
      panel?.classList.remove('hidden')
      button?.setAttribute('aria-expanded', 'true')
    })
  }
  await waitForVisible(page, '#openCorpusMenuPanel')
  await page.locator(actionSelector).click({ force: true })
  await page.evaluate(() => {
    const panel = document.getElementById('openCorpusMenuPanel')
    const button = document.getElementById('openCorpusMenuButton')
    panel?.classList.add('hidden')
    button?.setAttribute('aria-expanded', 'false')
  })
  await waitForHidden(page, '#openCorpusMenuPanel')
}

const TAB_SECTION_ID_BY_TAB = Object.freeze({
  stats: 'statsSection',
  kwic: 'kwicSection',
  collocate: 'collocateSection',
  compare: 'compareSection',
  locator: 'locatorSection',
  chiSquare: 'chiSquareSection',
  ngram: 'ngramSection'
})

async function clickTab(page, tabId) {
  const sectionId = TAB_SECTION_ID_BY_TAB[tabId] || ''
  const tabButton = page.locator(`.tab-button[data-tab="${tabId}"]`)
  const isTabActivated = async () => page.evaluate(
    ({ currentTabId, currentSectionId }) => {
      const button = document.querySelector(`.tab-button[data-tab="${currentTabId}"]`)
      const section = currentSectionId ? document.getElementById(currentSectionId) : null
      const buttonActive = Boolean(button?.classList.contains('active'))
      const sectionVisible = section ? !section.classList.contains('hidden') : false
      return buttonActive || sectionVisible
    },
    { currentTabId: tabId, currentSectionId: sectionId }
  )

  try {
    await tabButton.click()
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error || '')
    const shouldForceClick =
      message.includes('intercepts pointer events') ||
      message.includes('element is not receiving pointer events')
    if (!shouldForceClick) throw error
    await tabButton.click({ force: true })
  }

  if (!(await isTabActivated())) {
    await page.evaluate(currentTabId => {
      document.querySelector(`.tab-button[data-tab="${currentTabId}"]`)?.click()
    }, tabId)
  }

  if (sectionId) {
    await page.waitForFunction(
      ({ currentTabId, currentSectionId }) => {
        const button = document.querySelector(`.tab-button[data-tab="${currentTabId}"]`)
        const section = document.getElementById(currentSectionId)
        return Boolean(button?.classList.contains('active')) && Boolean(section) && !section.classList.contains('hidden')
      },
      { currentTabId: tabId, currentSectionId: sectionId }
    )
  }
}

async function writeDocxFixture(filePath) {
  await fs.writeFile(filePath, Buffer.from(DOCX_FIXTURE_BASE64, 'base64'))
}

async function writePdfFixture(filePath, lines) {
  await fs.writeFile(filePath, buildSimplePdfBuffer(lines))
}

async function readSingleBackupDir(backupRoot) {
  const entries = await fs.readdir(backupRoot)
  assert.equal(entries.length, 1)
  return path.join(backupRoot, entries[0])
}

async function getUserDataDir(electronApp) {
  return electronApp.evaluate(async ({ app }) => app.getPath('userData'))
}

async function findCorpusIdByName(corporaDir, expectedName) {
  const entryNames = await fs.readdir(corporaDir)
  for (const entryName of entryNames) {
    const metaPath = path.join(corporaDir, entryName, 'meta.json')
    try {
      const rawMeta = await fs.readFile(metaPath, 'utf-8')
      const meta = JSON.parse(rawMeta)
      if (meta?.name === expectedName || meta?.originalName === `${expectedName}.txt`) {
        return entryName
      }
    } catch {
      continue
    }
  }

  throw new Error(`未找到语料：${expectedName}`)
}

function escapeRegExp(text) {
  return String(text).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

test('Electron smoke: main shell, tabs and modals load normally', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-smoke-'))
  let electronApp = null

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome)
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []

  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await page.locator('#openCorpusMenuButton').waitFor()
  await page.locator('#workspaceCorpusValue').waitFor()

  assert.equal(await page.title(), APP_NAME)
  assert.equal((await page.locator('h1').textContent())?.trim(), APP_NAME)
  assert.equal((await page.locator('#workspaceCorpusValue').textContent())?.trim(), '未载入')
  assert.equal(await isVisible(page, '#statsSection'), true)
  assert.equal(await isVisible(page, '#kwicSection'), false)

  await clickTab(page, 'kwic')
  await page.waitForFunction(() => !document.getElementById('kwicSection').classList.contains('hidden'))
  assert.equal(await isVisible(page, '#kwicSection'), true)

  await clickTab(page, 'collocate')
  await page.waitForFunction(() => !document.getElementById('collocateSection').classList.contains('hidden'))
  assert.equal(await isVisible(page, '#collocateSection'), true)

  await page.locator('#uiSettingsButton').click()
  await page.waitForFunction(() => !document.getElementById('uiSettingsModal').classList.contains('hidden'))
  assert.equal(await isVisible(page, '#uiSettingsModal'), true)
  await page.locator('#debugLoggingToggle').waitFor()
  await page.locator('#systemNotificationsToggle').waitFor()
  await page.locator('#windowAttentionToggle').waitFor()
  await page.locator('#notifyAnalysisCompleteToggle').waitFor()
  await page.locator('#notifyUpdateDownloadedToggle').waitFor()
  await page.locator('#notifyDiagnosticsExportToggle').waitFor()
  await page.locator('#followSystemAccessibilityToggle').waitFor()
  await page.locator('#systemThemeButton').waitFor()
  await page.locator('#exportDiagnosticsButton').waitFor()
  await page.locator('#reportIssueButton').waitFor()
  await page.locator('#darkThemeButton').click()
  await page.waitForFunction(() => document.body.getAttribute('data-theme') === 'dark')
  await page.locator('#systemThemeButton').click()
  await page.waitForFunction(() => {
    const value = document.getElementById('themeModeValue')?.textContent || ''
    return value.includes('跟随系统')
  })
  await page.locator('#closeUiSettingsButton').click()
  await page.waitForFunction(() => document.getElementById('uiSettingsModal').classList.contains('hidden'))

  assert.equal(await isVisible(page, '#previewPanelBody'), false)
  await page.locator('#previewToggleButton').click()
  assert.equal(await isVisible(page, '#previewPanelBody'), true)
  await page.locator('#previewToggleButton').click()
  assert.equal(await isVisible(page, '#previewPanelBody'), false)

  await page.locator('#aboutButton').click()
  await waitForVisible(page, '#helpCenterModal')
  await page.waitForFunction(expectedName => document.getElementById('helpCenterTitle').textContent.includes(expectedName), APP_NAME)
  const helpCenterText = (await page.locator('#helpCenterModal').textContent()) || ''
  assert.match(helpCenterText, new RegExp(`当前版本 v${escapeRegExp(APP_VERSION)}`))
  assert.match(helpCenterText, /作者：邹羽轩/)
  assert.match(helpCenterText, /https:\/\/github\.com\/zzwdh\/WordZ/)
  assert.match(helpCenterText, /重新查看首次教程/)
  assert.match(helpCenterText, /使用说明/)
  assert.match(helpCenterText, /发布说明/)
  await page.locator('#reopenTutorialButton').click()
  await waitForHidden(page, '#helpCenterModal')
  await waitForVisible(page, '#welcomeOverlay')
  assert.equal(await isVisible(page, '#welcomeTutorialBlock'), true)
  await page.locator('#closeWelcomeButton').click()
  await waitForHidden(page, '#welcomeOverlay')

  await page.locator('#checkUpdateButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('feedbackTitle').textContent.includes('自动更新暂不可用'))
  assert.match((await page.locator('#feedbackMessage').textContent()) || '', /开发环境|自动更新/)
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')

  await page.locator('#taskCenterButton').click()
  await page.waitForFunction(() => !document.getElementById('taskCenterPanel').classList.contains('hidden'))
  assert.equal(await isVisible(page, '#taskCenterPanel'), true)
  await page.locator('#closeTaskCenterButton').click()
  await page.waitForFunction(() => document.getElementById('taskCenterPanel').classList.contains('hidden'))

  await chooseCorpusMenuAction(page, '#libraryButton')
  await page.waitForFunction(() => !document.getElementById('libraryModal').classList.contains('hidden'))
  await page.waitForFunction(() => document.getElementById('libraryMeta').textContent.trim() !== '正在读取本地语料库...')
  assert.equal(await isVisible(page, '#libraryModal'), true)
  assert.match((await page.locator('#libraryTargetChip').textContent()) || '', /当前查看：/)

  await page.locator('#recycleBinButton').click()
  await waitForVisible(page, '#recycleModal')
  assert.match((await page.locator('#recycleMeta').textContent()) || '', /共 \d+ 条项目/)
  await page.locator('#closeRecycleButton').click()
  await waitForHidden(page, '#recycleModal')

  await page.locator('#closeLibraryButton').click()
  await page.waitForFunction(() => document.getElementById('libraryModal').classList.contains('hidden'))

  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: import, library actions, analysis and export work end-to-end', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-e2e-'))
  const fixturePath = path.join(tempHome, 'smoke-sample.txt')
  const exportPath = path.join(tempHome, 'exports', 'stats-summary.csv')
  let electronApp = null

  await fs.mkdir(path.dirname(exportPath), { recursive: true })
  await fs.writeFile(
    fixturePath,
    [
      'rose red rose bloom bright',
      'rose bloom bright bloom rose',
      'bloom red rose bright bloom'
    ].join('\n'),
    'utf-8'
  )

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath]),
      CORPUS_LITE_SMOKE_SAVE_DIALOG_QUEUE: JSON.stringify([exportPath])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []

  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await page.locator('#openCorpusMenuButton').waitFor()

  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryMeta').textContent.trim() !== '正在读取本地语料库...')

  await page.locator('#createFolderButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackInput').fill('烟测项目')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('libraryFolderList').textContent.includes('烟测项目'))
  assert.match((await page.locator('#libraryTargetChip').textContent()) || '', /导入目标：烟测项目/)

  const createdFolderItem = page.locator('#libraryFolderList .library-folder-item').filter({ hasText: '烟测项目' }).first()
  await createdFolderItem.locator('[data-rename-folder-id]').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackInput').fill('烟测项目A')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('libraryFolderList').textContent.includes('烟测项目A'))
  assert.match((await page.locator('#libraryTargetChip').textContent()) || '', /导入目标：烟测项目A/)

  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'smoke-sample')
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('smoke-sample'))

  const importedCorpusRow = page.locator('#libraryTableWrapper tbody tr').filter({ hasText: 'smoke-sample' }).first()
  await importedCorpusRow.locator('[data-show-corpus-id]').click()
  await page.waitForFunction(() => document.getElementById('toastViewport').textContent.includes('已显示位置'))
  await importedCorpusRow.locator('[data-rename-corpus-id]').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackInput').fill('烟测语料A')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('烟测语料A'))

  const renamedCorpusRow = page.locator('#libraryTableWrapper tbody tr').filter({ hasText: '烟测语料A' }).first()
  await renamedCorpusRow.locator('select[data-move-folder-select]').selectOption('uncategorized')
  await renamedCorpusRow.locator('[data-move-corpus-id]').click()
  await page.waitForFunction(() => !document.getElementById('libraryTableWrapper').textContent.includes('烟测语料A'))

  await page.locator('#libraryFolderList [data-library-folder-id="uncategorized"]').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('烟测语料A'))

  const uncategorizedCorpusRow = page.locator('#libraryTableWrapper tbody tr').filter({ hasText: '烟测语料A' }).first()
  await uncategorizedCorpusRow.locator('[data-open-corpus-id]').click()
  await waitForHidden(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === '烟测语料A')
  assert.match((await page.locator('#workspaceCorpusNote').textContent()) || '', /未分类/)

  await page.locator('#countButton').click()
  await page.waitForFunction(() => document.getElementById('workspaceModeValue').textContent.trim() === '分析就绪')
  await page.waitForFunction(() => document.querySelectorAll('#tableWrapper tbody tr').length > 0)
  assert.match((await page.locator('#totalRowsInfo').textContent()) || '', /共 \d+ 个单词/)

  await clickTab(page, 'kwic')
  await page.locator('#kwicInput').fill('rose')
  await page.locator('#kwicButton').click()
  await page.waitForFunction(() => document.querySelectorAll('#kwicWrapper tbody tr').length > 0)
  assert.match((await page.locator('#kwicTotalRowsInfo').textContent()) || '', /共 \d+ 条结果/)
  await page.locator('#kwicWrapper tbody tr').first().click()
  await page.waitForFunction(() => !document.getElementById('locatorSection').classList.contains('hidden'))
  await page.waitForFunction(() => document.querySelectorAll('#sentenceViewer tbody tr').length > 0)

  await clickTab(page, 'stats')
  await page.locator('#copyStatsButton').click()
  await page.waitForFunction(() => document.getElementById('toastViewport').textContent.includes('导出完成'))

  await page.locator('#taskCenterButton').click()
  await waitForVisible(page, '#taskCenterPanel')
  await page.waitForFunction(() => {
    const text = document.getElementById('taskCenterList').textContent
    return text.includes('统计结果') && text.includes('KWIC 检索') && text.includes('已完成')
  })
  await page.keyboard.press('Escape')
  await waitForHidden(page, '#taskCenterPanel')

  const exportedContent = await fs.readFile(exportPath, 'utf-8')
  assert.match(exportedContent, /指标/)
  assert.match(exportedContent, /总词数（Token）/)

  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.locator('#libraryFolderList [data-library-folder-id="uncategorized"]').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('烟测语料A'))
  const deletableCorpusRow = page.locator('#libraryTableWrapper tbody tr').filter({ hasText: '烟测语料A' }).first()
  await deletableCorpusRow.locator('[data-delete-corpus-id]').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => !document.getElementById('libraryTableWrapper').textContent.includes('烟测语料A'))

  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: library-wide KWIC search opens matching saved corpora', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-library-kwic-smoke-'))
  const firstFixturePath = path.join(tempHome, 'cross-a.txt')
  const secondFixturePath = path.join(tempHome, 'cross-b.txt')
  let electronApp = null

  await fs.writeFile(firstFixturePath, 'red rose blooms\nsilver wind', 'utf-8')
  await fs.writeFile(secondFixturePath, 'white rose fades\nrose returns softly', 'utf-8')

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([firstFixturePath, secondFixturePath])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryMeta').textContent.trim() !== '正在读取本地语料库...')

  await page.locator('#createFolderButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackInput').fill('检索库A')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('libraryFolderList').textContent.includes('检索库A'))
  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('cross-a'))

  await page.locator('#createFolderButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackInput').fill('检索库B')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('libraryFolderList').textContent.includes('检索库B'))
  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('cross-b'))

  await page.locator('#closeLibraryButton').click()
  await waitForHidden(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'cross-b')

  await clickTab(page, 'kwic')
  await page.locator('#kwicInput').fill('rose')
  await page.locator('#kwicScopeSelect').selectOption('library')
  await page.locator('#kwicButton').click()
  await page.waitForFunction(() => document.querySelectorAll('#kwicWrapper tbody tr').length >= 3)
  assert.match((await page.locator('#kwicMeta').textContent()) || '', /全部本地语料/)
  assert.match((await page.locator('#kwicWrapper').textContent()) || '', /cross-a/)
  assert.match((await page.locator('#kwicWrapper').textContent()) || '', /cross-b/)

  const targetRow = page.locator('#kwicWrapper tbody tr').filter({ hasText: 'cross-a' }).first()
  await targetRow.click()
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'cross-a')
  await page.waitForFunction(() => !document.getElementById('locatorSection').classList.contains('hidden'))
  await page.waitForFunction(() => document.querySelectorAll('#sentenceViewer tbody tr').length > 0)
  assert.match((await page.locator('#workspaceCorpusNote').textContent()) || '', /检索库A/)

  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: multi-corpus comparison analysis renders after loading multiple saved corpora', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-compare-smoke-'))
  const firstFixturePath = path.join(tempHome, 'compare-a.txt')
  const secondFixturePath = path.join(tempHome, 'compare-b.txt')
  let electronApp = null

  await fs.writeFile(firstFixturePath, 'rose rose bloom bright', 'utf-8')
  await fs.writeFile(secondFixturePath, 'rose bright bright wind', 'utf-8')

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([firstFixturePath, secondFixturePath])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryMeta').textContent.trim() !== '正在读取本地语料库...')

  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('compare-a'))
  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('compare-b'))

  const firstRow = page.locator('#libraryTableWrapper tbody tr').filter({ hasText: 'compare-a' }).first()
  const secondRow = page.locator('#libraryTableWrapper tbody tr').filter({ hasText: 'compare-b' }).first()
  await firstRow.locator('[data-select-corpus-id]').check()
  await secondRow.locator('[data-select-corpus-id]').check()
  await page.waitForFunction(() => document.getElementById('loadSelectedCorporaButton').textContent.includes('2'))

  await page.locator('#loadSelectedCorporaButton').click()
  await waitForHidden(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === '已选 2 条语料')
  assert.match((await page.locator('#selectedCorporaWrapper').textContent()) || '', /compare-a/)
  assert.match((await page.locator('#selectedCorporaWrapper').textContent()) || '', /compare-b/)

  await page.locator('#countButton').click()
  await page.waitForFunction(() => document.getElementById('workspaceModeValue').textContent.trim() === '分析就绪')
  await clickTab(page, 'compare')
  await page.waitForFunction(() => !document.getElementById('compareSection').classList.contains('hidden'))
  await page.waitForFunction(() => document.querySelectorAll('#compareWrapper tbody tr').length > 0)

  assert.match((await page.locator('#compareSummaryWrapper').textContent()) || '', /compare-a/)
  assert.match((await page.locator('#compareSummaryWrapper').textContent()) || '', /compare-b/)
  assert.match((await page.locator('#compareMeta').textContent()) || '', /已对比 2 条语料/)
  assert.match((await page.locator('#compareWrapper').textContent()) || '', /rose/)
  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: saved workspace is restored on next launch', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-workspace-restore-smoke-'))
  const fixturePath = path.join(tempHome, 'workspace-restore-source.txt')
  let firstApp = null
  let secondApp = null

  await fs.writeFile(
    fixturePath,
    [
      'rose red rose bloom bright',
      'rose bloom bright bloom rose'
    ].join('\n'),
    'utf-8'
  )

  t.after(async () => {
    if (firstApp) {
      await firstApp.close().catch(() => {})
    }
    if (secondApp) {
      await secondApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  firstApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath])
    })
  })

  let page = await firstApp.firstWindow()
  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#saveImportButton')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'workspace-restore-source')
  await page.locator('#pageSizeSelect').selectOption('100')
  await clickTab(page, 'kwic')
  await page.locator('#kwicInput').fill('rose')
  await page.waitForFunction(() => document.getElementById('kwicInput').value === 'rose')
  await page.waitForTimeout(300)
  await firstApp.close()
  firstApp = null

  secondApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome)
  })

  page = await secondApp.firstWindow()
  await page.waitForFunction(() => {
    const prompt = document.getElementById('welcomeRestorePrompt')
    return Boolean(prompt) && !prompt.classList.contains('hidden')
  })
  await prepareWindow(page, { restorePrompt: 'restore' })
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'workspace-restore-source')
  await page.waitForFunction(() => !document.getElementById('kwicSection').classList.contains('hidden'))
  assert.equal((await page.locator('#kwicInput').inputValue()).trim(), 'rose')
  assert.equal(await page.locator('#pageSizeSelect').inputValue(), '100')
})

test('Electron smoke: recent open entries reopen the latest quick corpus', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-recent-open-smoke-'))
  const fixturePath = path.join(tempHome, 'recent-open-source.txt')
  let firstApp = null
  let secondApp = null

  await fs.writeFile(
    fixturePath,
    [
      'orchid quiet orchid signal',
      'signal orchid returns softly'
    ].join('\n'),
    'utf-8'
  )

  t.after(async () => {
    if (firstApp) {
      await firstApp.close().catch(() => {})
    }
    if (secondApp) {
      await secondApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  firstApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath])
    })
  })

  let page = await firstApp.firstWindow()
  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#quickOpenButton')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'recent-open-source')
  const recentDocuments = await firstApp.evaluate(async ({ app }) => {
    return typeof app.getRecentDocuments === 'function' ? app.getRecentDocuments() : []
  })
  assert.ok(Array.isArray(recentDocuments))
  await firstApp.close()
  firstApp = null

  secondApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome)
  })

  page = await secondApp.firstWindow()
  await prepareWindow(page)
  await page.locator('#openCorpusMenuButton').click()
  await waitForVisible(page, '#openCorpusMenuPanel')
  await waitForVisible(page, '#recentOpenSection')
  await page.locator('[data-recent-open-index="0"]').click()
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'recent-open-source')
})

test('Electron smoke: app launch with a file path opens the corpus automatically', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-launch-open-smoke-'))
  const fixturePath = path.join(tempHome, 'launch-open.txt')
  let electronApp = null

  await fs.writeFile(
    fixturePath,
    [
      'aurora signal returns softly',
      'signal lines stay bright'
    ].join('\n'),
    'utf-8'
  )

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot, fixturePath],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome)
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await page.waitForLoadState('domcontentloaded')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'launch-open')
  assert.match((await page.locator('#workspaceCorpusNote').textContent()) || '', /Quick Corpus/)
  assert.equal(await isVisible(page, '#welcomeOverlay'), false)
  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: recycle bin restores and purges deleted entries', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-recycle-smoke-'))
  const fixturePath = path.join(tempHome, 'recycle-source.txt')
  let electronApp = null

  await fs.writeFile(
    fixturePath,
    [
      'rose red rose bloom bright',
      'rose bloom bright bloom rose'
    ].join('\n'),
    'utf-8'
  )

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath, fixturePath])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryMeta').textContent.trim() !== '正在读取本地语料库...')

  await page.locator('#createFolderButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackInput').fill('回收箱项目')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('libraryFolderList').textContent.includes('回收箱项目'))

  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('recycle-source'))

  let corpusRow = page.locator('#libraryTableWrapper tbody tr').filter({ hasText: 'recycle-source' }).first()
  await corpusRow.locator('[data-delete-corpus-id]').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => !document.getElementById('libraryTableWrapper').textContent.includes('recycle-source'))

  await page.locator('#recycleBinButton').click()
  await waitForVisible(page, '#recycleModal')
  await page.waitForFunction(() => document.getElementById('recycleTableWrapper').textContent.includes('recycle-source'))

  let recycleRow = page.locator('#recycleTableWrapper tbody tr').filter({ hasText: 'recycle-source' }).first()
  await recycleRow.locator('[data-show-recycle-entry-id]').click()
  await page.waitForFunction(() => document.getElementById('toastViewport').textContent.includes('已显示位置'))
  await recycleRow.locator('[data-restore-recycle-entry-id]').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => !document.getElementById('recycleTableWrapper').textContent.includes('recycle-source'))

  await page.locator('#closeRecycleButton').click()
  await waitForHidden(page, '#recycleModal')
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('recycle-source'))

  corpusRow = page.locator('#libraryTableWrapper tbody tr').filter({ hasText: 'recycle-source' }).first()
  await corpusRow.locator('[data-delete-corpus-id]').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => !document.getElementById('libraryTableWrapper').textContent.includes('recycle-source'))

  await page.locator('#recycleBinButton').click()
  await waitForVisible(page, '#recycleModal')
  await page.waitForFunction(() => document.getElementById('recycleTableWrapper').textContent.includes('recycle-source'))
  recycleRow = page.locator('#recycleTableWrapper tbody tr').filter({ hasText: 'recycle-source' }).first()
  await recycleRow.locator('[data-purge-recycle-entry-id]').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => !document.getElementById('recycleTableWrapper').textContent.includes('recycle-source'))
  await page.locator('#closeRecycleButton').click()
  await waitForHidden(page, '#recycleModal')

  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('recycle-source'))

  const folderItem = page.locator('#libraryFolderList .library-folder-item').filter({ hasText: '回收箱项目' }).first()
  await folderItem.locator('[data-delete-folder-id]').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => !document.getElementById('libraryFolderList').textContent.includes('回收箱项目'))

  await page.locator('#recycleBinButton').click()
  await waitForVisible(page, '#recycleModal')
  await page.waitForFunction(() => document.getElementById('recycleTableWrapper').textContent.includes('回收箱项目'))
  const recycleFolderRow = page.locator('#recycleTableWrapper tbody tr').filter({ hasText: '回收箱项目' }).first()
  await recycleFolderRow.locator('[data-restore-recycle-entry-id]').click()
  await waitForVisible(page, '#feedbackModal')
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => !document.getElementById('recycleTableWrapper').textContent.includes('回收箱项目'))
  await page.locator('#closeRecycleButton').click()
  await waitForHidden(page, '#recycleModal')

  await page.waitForFunction(() => document.getElementById('libraryFolderList').textContent.includes('回收箱项目'))
  await page.locator('#libraryFolderList .library-folder-item').filter({ hasText: '回收箱项目' }).first().locator('[data-library-folder-id]').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('recycle-source'))

  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: backup, restore and repair library flows work end-to-end', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-restore-smoke-'))
  const firstFixturePath = path.join(tempHome, 'backup-source-a.txt')
  const secondFixturePath = path.join(tempHome, 'restore-extra-b.txt')
  const backupRoot = path.join(tempHome, 'backup-root')
  let firstApp = null
  let secondApp = null

  await fs.mkdir(backupRoot, { recursive: true })
  await fs.writeFile(firstFixturePath, 'alpha beta gamma', 'utf-8')
  await fs.writeFile(secondFixturePath, 'delta epsilon zeta', 'utf-8')

  t.after(async () => {
    if (firstApp) {
      await firstApp.close().catch(() => {})
    }
    if (secondApp) {
      await secondApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  firstApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([firstFixturePath, backupRoot])
    })
  })

  let page = await firstApp.firstWindow()
  const firstPageErrors = []
  page.on('pageerror', error => {
    firstPageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryMeta').textContent.trim() !== '正在读取本地语料库...')

  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('backup-source-a'))

  await page.locator('#backupLibraryButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('feedbackTitle').textContent.includes('备份完成'))
  assert.match((await page.locator('#feedbackMessage').textContent()) || '', /语料数量：\d+/)
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')

  assert.deepEqual(firstPageErrors, [])
  await firstApp.close()
  firstApp = null

  const backupDir = await readSingleBackupDir(backupRoot)

  secondApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([secondFixturePath, backupDir])
    })
  })

  page = await secondApp.firstWindow()
  const secondPageErrors = []
  page.on('pageerror', error => {
    secondPageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('backup-source-a'))

  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('restore-extra-b'))

  await page.locator('#restoreLibraryButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('feedbackTitle').textContent.includes('恢复本地语料库'))
  await page.locator('#feedbackConfirmButton').click()
  await page.waitForFunction(() => {
    const modal = document.getElementById('feedbackModal')
    const title = document.getElementById('feedbackTitle').textContent
    return !modal.classList.contains('hidden') && title.includes('恢复完成')
  })
  assert.match((await page.locator('#feedbackMessage').textContent()) || '', /恢复后的语料数量：\d+/)
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => {
    const text = document.getElementById('libraryTableWrapper').textContent
    return text.includes('backup-source-a') && !text.includes('restore-extra-b')
  })

  await page.locator('#repairLibraryButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('feedbackTitle').textContent.includes('修复本地语料库'))
  await page.locator('#feedbackConfirmButton').click()
  await page.waitForFunction(() => {
    const modal = document.getElementById('feedbackModal')
    const title = document.getElementById('feedbackTitle').textContent
    return !modal.classList.contains('hidden') && title.includes('修复完成')
  })
  assert.match((await page.locator('#feedbackMessage').textContent()) || '', /语料库结构检查完成|语料库检查与修复已完成/)
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')

  assert.deepEqual(secondPageErrors, [])
})

test('Electron smoke: invalid backup restore is rejected without mutating the library', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-invalid-restore-smoke-'))
  const fixturePath = path.join(tempHome, 'restore-safe-source.txt')
  const invalidBackupDir = path.join(tempHome, 'invalid-backup-dir')
  let electronApp = null

  await fs.mkdir(invalidBackupDir, { recursive: true })
  await fs.writeFile(path.join(invalidBackupDir, 'readme.txt'), 'not a backup', 'utf-8')
  await fs.writeFile(fixturePath, 'alpha beta gamma', 'utf-8')

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath, invalidBackupDir])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryMeta').textContent.trim() !== '正在读取本地语料库...')

  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('restore-safe-source'))

  await page.locator('#restoreLibraryButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('feedbackTitle').textContent.includes('恢复本地语料库'))
  await page.locator('#feedbackConfirmButton').click()
  await page.waitForFunction(() => {
    const modal = document.getElementById('feedbackModal')
    const title = document.getElementById('feedbackTitle').textContent
    return !modal.classList.contains('hidden') && title.includes('恢复失败')
  })
  assert.match((await page.locator('#feedbackMessage').textContent()) || '', /所选目录不是有效的语料库备份/)
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('restore-safe-source'))

  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: repair recovers malformed library entries and quarantines bad data', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-repair-smoke-'))
  const fixturePath = path.join(tempHome, 'repair-source.txt')
  let electronApp = null

  await fs.writeFile(fixturePath, 'rose bloom bright', 'utf-8')

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryMeta').textContent.trim() !== '正在读取本地语料库...')
  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('repair-source'))

  const userDataDir = await getUserDataDir(electronApp)
  const libraryDir = path.join(userDataDir, 'corpus-library')
  const uncategorizedCorporaDir = path.join(libraryDir, 'folders', 'uncategorized', 'corpora')
  const corpusId = await findCorpusIdByName(uncategorizedCorporaDir, 'repair-source')
  const corpusDir = path.join(uncategorizedCorporaDir, corpusId)

  await fs.rm(path.join(corpusDir, 'meta.json'), { force: true })
  await fs.mkdir(path.join(libraryDir, 'folders', 'bad folder'), { recursive: true })
  await fs.writeFile(path.join(libraryDir, 'folders', 'bad folder', 'note.txt'), 'broken folder', 'utf-8')
  await fs.mkdir(path.join(uncategorizedCorporaDir, 'bad corpus'), { recursive: true })
  await fs.writeFile(path.join(uncategorizedCorporaDir, 'bad corpus', 'content.txt'), 'broken corpus', 'utf-8')

  await page.locator('#repairLibraryButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('feedbackTitle').textContent.includes('修复本地语料库'))
  await page.locator('#feedbackConfirmButton').click()
  await page.waitForFunction(() => {
    const modal = document.getElementById('feedbackModal')
    const title = document.getElementById('feedbackTitle').textContent
    return !modal.classList.contains('hidden') && title.includes('修复完成')
  })
  const repairMessage = (await page.locator('#feedbackMessage').textContent()) || ''
  assert.match(repairMessage, /补回缺失元数据：1/)
  assert.match(repairMessage, /隔离异常文件夹：1/)
  assert.match(repairMessage, /隔离异常语料：1/)
  await page.locator('#feedbackConfirmButton').click()
  await waitForHidden(page, '#feedbackModal')

  await page.waitForFunction(expectedCorpusId => {
    const text = document.getElementById('libraryTableWrapper').textContent
    const folderText = document.getElementById('libraryFolderList').textContent
    return text.includes(expectedCorpusId) && !text.includes('bad corpus') && !folderText.includes('bad folder')
  }, corpusId)

  const repairedCorpusRow = page.locator('#libraryTableWrapper tbody tr').filter({ hasText: corpusId }).first()
  await repairedCorpusRow.locator('[data-open-corpus-id]').click()
  await waitForHidden(page, '#libraryModal')
  await page.waitForFunction(expectedCorpusId => document.getElementById('workspaceCorpusValue').textContent.trim() === expectedCorpusId, corpusId)

  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: docx quick open and csv/xlsx exports work end-to-end', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-docx-smoke-'))
  const docxPath = path.join(tempHome, 'smoke-docx.docx')
  const csvExportPath = path.join(tempHome, 'exports', 'stats-summary.csv')
  const xlsxExportPath = path.join(tempHome, 'exports', 'freq-page.xlsx')
  let electronApp = null

  await fs.mkdir(path.dirname(csvExportPath), { recursive: true })
  await writeDocxFixture(docxPath)

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([docxPath]),
      CORPUS_LITE_SMOKE_SAVE_DIALOG_QUEUE: JSON.stringify([csvExportPath, xlsxExportPath])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []

  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await page.locator('#openCorpusMenuButton').waitFor()

  await chooseCorpusMenuAction(page, '#quickOpenButton')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'smoke-docx')
  assert.match((await page.locator('#previewBox').textContent()) || '', /rose bloom bright rose/)

  await page.locator('#countButton').click()
  await page.waitForFunction(() => document.getElementById('workspaceModeValue').textContent.trim() === '分析就绪')
  await page.waitForFunction(() => document.querySelectorAll('#tableWrapper tbody tr').length > 0)

  await page.locator('#copyStatsButton').click()
  await page.waitForFunction(() => document.getElementById('toastViewport').textContent.includes('导出完成'))
  const csvContent = await fs.readFile(csvExportPath, 'utf-8')
  assert.match(csvContent, /指标/)
  assert.match(csvContent, /总词数（Token）/)

  await page.locator('#copyFreqButton').click()
  await page.waitForFunction(() => {
    const toastText = document.getElementById('toastViewport').textContent
    return toastText.includes('导出完成') && toastText.includes('freq-page.xlsx')
  })
  const workbook = new ExcelJS.Workbook()
  await workbook.xlsx.readFile(xlsxExportPath)
  const worksheet = workbook.getWorksheet('Sheet1')
  assert.ok(worksheet)
  assert.equal(worksheet.getRow(1).getCell(1).text, '词')
  assert.equal(worksheet.getRow(2).getCell(1).text, 'rose')

  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: pdf quick open and saved import work end-to-end', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-pdf-smoke-'))
  const pdfPath = path.join(tempHome, 'smoke-pdf.pdf')
  let electronApp = null

  await writePdfFixture(pdfPath, ['rose bloom bright', 'pdf second line'])

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([pdfPath, pdfPath])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#quickOpenButton')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'smoke-pdf')
  assert.match((await page.locator('#previewBox').textContent()) || '', /rose bloom bright/)
  assert.match((await page.locator('#previewBox').textContent()) || '', /pdf second line/)

  await page.locator('#countButton').click()
  await page.waitForFunction(() => document.getElementById('workspaceModeValue').textContent.trim() === '分析就绪')
  await page.waitForFunction(() => document.getElementById('tableWrapper').textContent.includes('rose'))

  await chooseCorpusMenuAction(page, '#saveImportButton')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'smoke-pdf')

  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('smoke-pdf'))
  await page.locator('#closeLibraryButton').click()
  await waitForHidden(page, '#libraryModal')

  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: gb18030 txt files open and import without mojibake', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-gb18030-smoke-'))
  const fixturePath = path.join(tempHome, 'gb18030-sample.txt')
  let electronApp = null

  await fs.writeFile(
    fixturePath,
    iconv.encode(
      [
        '春天 花开 词频 分析',
        '花开 春天 语料 工具'
      ].join('\n'),
      'gb18030'
    )
  )

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath, fixturePath])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#quickOpenButton')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'gb18030-sample')
  assert.match((await page.locator('#previewBox').textContent()) || '', /春天 花开 词频 分析/)

  await page.locator('#countButton').click()
  await page.waitForFunction(() => document.getElementById('workspaceModeValue').textContent.trim() === '分析就绪')
  await page.waitForFunction(() => document.getElementById('tableWrapper').textContent.includes('春天'))

  await chooseCorpusMenuAction(page, '#saveImportButton')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'gb18030-sample')
  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('gb18030-sample'))
  await page.locator('#closeLibraryButton').click()
  await waitForHidden(page, '#libraryModal')

  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: cancel actions update task center and keep UI responsive', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-cancel-smoke-'))
  const fixturePath = path.join(tempHome, 'cancel-source.txt')
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

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath]),
      CORPUS_LITE_SMOKE_ANALYSIS_DELAY_MS: '1800'
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#quickOpenButton')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'cancel-source')

  await page.locator('#countButton').click()
  await waitForVisible(page, '#cancelStatsButton')
  await page.locator('#cancelStatsButton').click()
  await page.waitForFunction(() => document.getElementById('cancelStatsButton').classList.contains('hidden') && !document.getElementById('countButton').disabled)

  await page.locator('#taskCenterButton').click()
  await waitForVisible(page, '#taskCenterPanel')
  await page.waitForFunction(() => {
    const text = document.getElementById('taskCenterList').textContent
    return text.includes('统计结果') && text.includes('已取消')
  })

  await clickTab(page, 'kwic')
  await page.locator('#kwicInput').fill('rose')
  await page.locator('#kwicButton').click()
  await waitForVisible(page, '#cancelKwicButton')
  await page.locator('#cancelKwicButton').click()
  await page.waitForFunction(() => document.getElementById('cancelKwicButton').classList.contains('hidden') && !document.getElementById('kwicButton').disabled)
  await page.waitForFunction(() => {
    const text = document.getElementById('taskCenterList').textContent
    return text.includes('统计结果') && text.includes('KWIC 检索') && (text.match(/已取消/g) || []).length >= 2
  })

  await clickTab(page, 'collocate')
  await page.locator('#collocateInput').fill('rose')
  await page.locator('#collocateButton').click()
  await waitForVisible(page, '#cancelCollocateButton')
  await page.locator('#cancelCollocateButton').click()
  await page.waitForFunction(() => document.getElementById('cancelCollocateButton').classList.contains('hidden') && !document.getElementById('collocateButton').disabled)
  await page.waitForFunction(() => {
    const text = document.getElementById('taskCenterList').textContent
    return text.includes('Collocate 统计') && (text.match(/已取消/g) || []).length >= 3
  })

  await page.keyboard.press('Escape')
  await waitForHidden(page, '#taskCenterPanel')
  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: analysis emits observable system notifications, attention badges and window progress updates', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-native-observer-smoke-'))
  const fixturePath = path.join(tempHome, 'observer-source.txt')
  let electronApp = null

  await fs.writeFile(
    fixturePath,
    [
      'cyber signal network cyber matrix',
      'signal cyber archive system signal',
      'archive network cyber signal matrix'
    ].join('\n'),
    'utf-8'
  )

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await launchSmokeElectronApp({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([fixturePath])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await chooseCorpusMenuAction(page, '#quickOpenButton')
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'observer-source')

  await page.locator('#countButton').click()
  await page.waitForFunction(() => document.getElementById('workspaceModeValue').textContent.trim() === '分析就绪')

  await clickTab(page, 'kwic')
  await page.locator('#kwicInput').fill('cyber')
  await page.locator('#kwicButton').click()
  await page.waitForFunction(() => document.getElementById('kwicWrapper').textContent.includes('cyber'))
  await page.waitForFunction(async () => {
    const result = await window.electronAPI.getSmokeObserverState()
    const events = result?.state?.windowAttention || []
    return events.some(event => event?.winningEntry?.source === 'task-center' && Number(event?.winningEntry?.count) >= 1)
  })

  await page.locator('#taskCenterButton').click()
  await waitForVisible(page, '#taskCenterPanel')
  await page.waitForFunction(async () => {
    const result = await window.electronAPI.getSmokeObserverState()
    const events = result?.state?.windowAttention || []
    return events.some(event => event?.winningEntry === null)
  })

  const observerState = await page.evaluate(async () => window.electronAPI.getSmokeObserverState())
  assert.equal(observerState.success, true)
  const notificationTitles = (observerState.state.notifications || []).map(item => item?.payload?.title || '')
  assert.ok(notificationTitles.includes('统计完成'))
  assert.ok(notificationTitles.includes('KWIC 检索完成'))

  const attentionEvents = observerState.state.windowAttention || []
  assert.ok(attentionEvents.some(event => event?.winningEntry?.source === 'task-center' && Number(event?.winningEntry?.count) >= 1))
  assert.ok(attentionEvents.some(event => event?.winningEntry === null))

  const progressEvents = observerState.state.windowProgress || []
  assert.ok(progressEvents.some(event => event?.winningEntry?.source === 'analysis' && event?.payload?.progress === 2))
  assert.ok(progressEvents.some(event => event?.winningEntry === null && event?.payload?.progress === -1))
  assert.deepEqual(pageErrors, [])
})

test('Electron smoke: system dialog cancellations are handled gracefully', { timeout: 120000 }, async t => {
  const tempHome = await fs.mkdtemp(path.join(os.tmpdir(), 'corpus-lite-dialog-cancel-smoke-'))
  const fixturePath = path.join(tempHome, 'dialog-cancel-source.txt')
  let electronApp = null

  await fs.writeFile(
    fixturePath,
    [
      'rose red rose bloom bright',
      'rose bloom bright bloom rose'
    ].join('\n'),
    'utf-8'
  )

  t.after(async () => {
    if (electronApp) {
      await electronApp.close().catch(() => {})
    }
    await fs.rm(tempHome, { recursive: true, force: true }).catch(() => {})
  })

  electronApp = await electron.launch({
    args: [appRoot],
    cwd: appRoot,
    env: buildIsolatedEnv(tempHome, {
      CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE: JSON.stringify([
        { canceled: true },
        { canceled: true },
        fixturePath,
        { canceled: true },
        { canceled: true }
      ]),
      CORPUS_LITE_SMOKE_SAVE_DIALOG_QUEUE: JSON.stringify([{ canceled: true }])
    })
  })

  const page = await electronApp.firstWindow()
  const pageErrors = []
  page.on('pageerror', error => {
    pageErrors.push(error.message || String(error))
  })

  await prepareWindow(page)
  await page.locator('#openCorpusMenuButton').waitFor()

  await chooseCorpusMenuAction(page, '#quickOpenButton')
  await page.waitForTimeout(250)
  assert.equal((await page.locator('#workspaceCorpusValue').textContent())?.trim(), '未载入')
  assert.equal(await isVisible(page, '#feedbackModal'), false)

  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryMeta').textContent.trim() !== '正在读取本地语料库...')

  await page.locator('#importToFolderButton').click()
  await page.waitForTimeout(250)
  assert.match((await page.locator('#libraryMeta').textContent()) || '', /共 0 条本地语料/)
  assert.equal((await page.locator('#workspaceCorpusValue').textContent())?.trim(), '未载入')

  await page.locator('#importToFolderButton').click()
  await page.waitForFunction(() => document.getElementById('workspaceCorpusValue').textContent.trim() === 'dialog-cancel-source')
  await page.locator('#closeLibraryButton').click()
  await waitForHidden(page, '#libraryModal')
  await page.locator('#countButton').click()
  await page.waitForFunction(() => document.getElementById('workspaceModeValue').textContent.trim() === '分析就绪')

  await page.locator('#copyStatsButton').click()
  await page.waitForFunction(() => document.getElementById('toastViewport').textContent.includes('未导出文件'))
  assert.equal(await isVisible(page, '#feedbackModal'), false)

  await chooseCorpusMenuAction(page, '#libraryButton')
  await waitForVisible(page, '#libraryModal')
  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('dialog-cancel-source'))

  await page.locator('#backupLibraryButton').click()
  await page.waitForFunction(() => document.getElementById('toastViewport').textContent.includes('未创建备份'))
  assert.equal(await isVisible(page, '#feedbackModal'), false)

  await page.locator('#restoreLibraryButton').click()
  await waitForVisible(page, '#feedbackModal')
  await page.waitForFunction(() => document.getElementById('feedbackTitle').textContent.includes('恢复本地语料库'))
  await page.locator('#feedbackConfirmButton').click()
  await page.waitForFunction(() => {
    const toastText = document.getElementById('toastViewport').textContent
    const modal = document.getElementById('feedbackModal')
    return toastText.includes('未恢复语料库') && modal.classList.contains('hidden')
  })

  await page.waitForFunction(() => document.getElementById('libraryTableWrapper').textContent.includes('dialog-cancel-source'))

  assert.deepEqual(pageErrors, [])
})
