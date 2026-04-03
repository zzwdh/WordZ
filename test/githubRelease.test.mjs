import test from 'node:test'
import assert from 'node:assert/strict'

import {
  buildPublishEnvironment,
  resolveGitHubReleaseConfig
} from '../scripts/github-release.mjs'

test('buildPublishEnvironment strips empty signing variables but keeps populated ones', () => {
  const env = buildPublishEnvironment({
    GITHUB_TOKEN: 'token-from-actions',
    CSC_LINK: '',
    CSC_KEY_PASSWORD: '   ',
    APPLE_ID: '',
    WIN_CSC_LINK: 'base64://certificate',
    CUSTOM_FLAG: 'keep-me'
  }, 'token-from-actions')

  assert.equal(env.GH_TOKEN, 'token-from-actions')
  assert.ok(!('CSC_LINK' in env))
  assert.ok(!('CSC_KEY_PASSWORD' in env))
  assert.ok(!('APPLE_ID' in env))
  assert.equal(env.WIN_CSC_LINK, 'base64://certificate')
  assert.equal(env.CUSTOM_FLAG, 'keep-me')
})

test('resolveGitHubReleaseConfig builds stable GitHub publish args and sanitized env', () => {
  const config = resolveGitHubReleaseConfig({
    GITHUB_REPOSITORY: 'zzwdh/WordZ',
    GITHUB_TOKEN: 'token-123',
    CSC_LINK: '',
    APPLE_API_KEY: '',
    WIN_CSC_LINK: ''
  }, ['--win'])

  assert.equal(config.owner, 'zzwdh')
  assert.equal(config.repo, 'WordZ')
  assert.equal(config.githubToken, 'token-123')
  assert.deepEqual(config.electronBuilderArgs.slice(0, 3), ['--publish', 'always', '--win'])
  assert.ok(config.electronBuilderArgs.includes('-c.extraMetadata.wordz.release.channel=stable'))
  assert.ok(config.electronBuilderArgs.includes('-c.extraMetadata.wordz.autoUpdate.github.owner=zzwdh'))
  assert.ok(config.electronBuilderArgs.includes('-c.extraMetadata.wordz.autoUpdate.github.repo=WordZ'))
  assert.equal(config.childEnv.GH_TOKEN, 'token-123')
  assert.ok(!('CSC_LINK' in config.childEnv))
  assert.ok(!('APPLE_API_KEY' in config.childEnv))
  assert.ok(!('WIN_CSC_LINK' in config.childEnv))
})

test('resolveGitHubReleaseConfig rejects retired electron mac release target', () => {
  assert.throws(() => {
    resolveGitHubReleaseConfig({
      GITHUB_REPOSITORY: 'zzwdh/WordZ',
      GITHUB_TOKEN: 'token-123'
    }, ['--mac'])
  }, /Electron macOS 发布链已退役/)
})
