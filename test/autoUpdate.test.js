const test = require('node:test')
const assert = require('node:assert/strict')

const { normalizeReleaseNotes, resolveAutoUpdateConfig } = require('../autoUpdate')

test('resolveAutoUpdateConfig disables updater cleanly when url is missing', () => {
  const config = resolveAutoUpdateConfig({
    packageManifest: {
      wordz: {
        autoUpdate: {
          enabled: true,
          provider: 'generic',
          url: '',
          channel: 'latest'
        }
      }
    },
    env: {},
    isPackaged: true,
    platform: 'win32'
  })

  assert.equal(config.enabled, false)
  assert.equal(config.configured, false)
  assert.match(config.disableReason, /尚未配置自动更新地址/)
})

test('resolveAutoUpdateConfig disables GitHub updater cleanly when owner/repo is missing', () => {
  const config = resolveAutoUpdateConfig({
    packageManifest: {
      wordz: {
        autoUpdate: {
          enabled: true,
          provider: 'github',
          channel: 'latest',
          github: {
            owner: '',
            repo: ''
          }
        }
      }
    },
    env: {},
    isPackaged: true,
    platform: 'win32'
  })

  assert.equal(config.enabled, false)
  assert.equal(config.configured, false)
  assert.equal(config.provider, 'github')
  assert.match(config.disableReason, /GitHub Releases 仓库/)
})

test('resolveAutoUpdateConfig honors env overrides for packaged desktop builds', () => {
  const config = resolveAutoUpdateConfig({
    packageManifest: {
      wordz: {
        autoUpdate: {
          enabled: true,
          provider: 'generic',
          url: 'https://updates.example.com/wordz',
          channel: 'latest'
        }
      }
    },
    env: {
      WORDZ_AUTO_UPDATE_URL: 'https://cdn.example.com/wordz',
      WORDZ_AUTO_UPDATE_CHANNEL: 'beta',
      WORDZ_AUTO_UPDATE_CHECK_DELAY_MS: '45000'
    },
    isPackaged: true,
    platform: 'darwin'
  })

  assert.equal(config.enabled, true)
  assert.equal(config.url, 'https://cdn.example.com/wordz')
  assert.equal(config.channel, 'beta')
  assert.equal(config.checkDelayMs, 45000)
})

test('resolveAutoUpdateConfig supports GitHub provider via repository metadata and env overrides', () => {
  const config = resolveAutoUpdateConfig({
    packageManifest: {
      repository: 'https://github.com/zouyuxuan/wordz.git',
      wordz: {
        autoUpdate: {
          enabled: true,
          provider: 'github',
          channel: 'latest',
          github: {
            owner: '',
            repo: ''
          }
        }
      }
    },
    env: {
      WORDZ_AUTO_UPDATE_GITHUB_REPO: 'wordz-desktop',
      WORDZ_AUTO_UPDATE_GITHUB_PRIVATE: 'true'
    },
    isPackaged: true,
    platform: 'darwin'
  })

  assert.equal(config.enabled, true)
  assert.equal(config.configured, true)
  assert.equal(config.provider, 'github')
  assert.equal(config.providerLabel, 'GitHub Releases')
  assert.equal(config.targetLabel, 'zouyuxuan/wordz-desktop')
  assert.deepEqual(config.github, {
    owner: 'zouyuxuan',
    repo: 'wordz-desktop',
    private: true
  })
})

test('normalizeReleaseNotes supports strings and structured arrays', () => {
  assert.deepEqual(normalizeReleaseNotes('- 第一条\n- 第二条'), ['第一条', '第二条'])
  assert.deepEqual(
    normalizeReleaseNotes([{ note: '  新增自动更新  ' }, ' 修复导出问题 ']),
    ['新增自动更新', '修复导出问题']
  )
})
