import test from 'node:test'
import assert from 'node:assert/strict'

import {
  parseRepositorySlug,
  evaluateLocalSecrets,
  evaluateGitHubSecrets
} from '../scripts/release-doctor.mjs'

test('parseRepositorySlug extracts owner/repo from repository urls', () => {
  assert.equal(parseRepositorySlug('https://github.com/zzwdh/WordZ.git'), 'zzwdh/WordZ')
  assert.equal(parseRepositorySlug({ url: 'git@github.com:zzwdh/WordZ.git' }), 'zzwdh/WordZ')
})

test('evaluateLocalSecrets detects complete local signing groups', () => {
  const result = evaluateLocalSecrets({
    CSC_LINK: 'base64-cert',
    CSC_KEY_PASSWORD: 'secret',
    APPLE_API_KEY: 'key',
    APPLE_API_KEY_ID: 'id',
    APPLE_API_ISSUER: 'issuer'
  })

  assert.equal(result.macCertificate, true)
  assert.equal(result.windowsCertificate, true)
  assert.equal(result.macNotarization, true)
})

test('evaluateGitHubSecrets reports missing recommended secrets', () => {
  const result = evaluateGitHubSecrets(['CSC_LINK', 'CSC_KEY_PASSWORD', 'APPLE_API_KEY'])

  assert.equal(result.macCertificate, true)
  assert.equal(result.windowsCertificate, true)
  assert.equal(result.macNotarization, false)
  assert.ok(result.missingRecommended.includes('APPLE_API_KEY_ID'))
  assert.ok(result.missingRecommended.includes('WIN_CSC_LINK'))
})
