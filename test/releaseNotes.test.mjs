import test from 'node:test'
import assert from 'node:assert/strict'

import { buildReleaseNotes } from '../scripts/generate-release-notes.mjs'

test('buildReleaseNotes generates markdown with versioned download guidance', () => {
  const markdown = buildReleaseNotes({
    name: 'corpus-lite',
    version: '1.2.3',
    productName: 'WordZ',
    description: '一个本地桌面语料分析工具。',
    wordz: {
      releaseNotes: [
        '新增自动更新支持',
        '修复 Windows 发布流程'
      ]
    }
  })

  assert.match(markdown, /^# WordZ 1\.2\.3/m)
  assert.match(markdown, /新增自动更新支持/)
  assert.match(markdown, /修复 Windows 发布流程/)
  assert.match(markdown, /发布渠道：稳定版/)
  assert.match(markdown, /WordZ-1\.2\.3-win-x64\.exe/)
  assert.match(markdown, /WordZ-1\.2\.3-mac-arm64\.dmg/)
  assert.match(markdown, /GitHub Releases 检查更新/)
})
