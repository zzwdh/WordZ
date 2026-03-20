import fs from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(__dirname, '..')

const REQUIRED_ASSETS = Object.freeze([
  'build/icon.png',
  'build/icon.ico',
  'build/icon.icns',
  'build/installer-sidebar.bmp',
  'build/installer-header.bmp',
  'build/license_zh.txt',
  'build/license_en.txt',
  'build/entitlements.mac.plist',
  'build/entitlements.mac.inherit.plist'
])

const GITHUB_SECRET_NAMES = Object.freeze([
  'CSC_LINK',
  'CSC_KEY_PASSWORD',
  'CSC_NAME',
  'WIN_CSC_LINK',
  'WIN_CSC_KEY_PASSWORD',
  'APPLE_API_KEY',
  'APPLE_API_KEY_ID',
  'APPLE_API_ISSUER',
  'APPLE_ID',
  'APPLE_APP_SPECIFIC_PASSWORD',
  'APPLE_TEAM_ID',
  'APPLE_KEYCHAIN',
  'APPLE_KEYCHAIN_PROFILE'
])

function normalizeText(value, fallback = '') {
  return String(value ?? fallback).trim()
}

function parseArgs(argv) {
  return {
    strict: argv.includes('--strict'),
    json: argv.includes('--json'),
    noGithub: argv.includes('--no-github')
  }
}

function parseRepositorySlug(repository) {
  const rawValue =
    typeof repository === 'string'
      ? repository
      : repository && typeof repository.url === 'string'
        ? repository.url
        : ''
  const normalizedValue = normalizeText(rawValue)
    .replace(/^git\+/, '')
    .replace(/\.git$/i, '')
    .replace(/\/+$/, '')

  const match = normalizedValue.match(
    /^(?:https?:\/\/github\.com\/|ssh:\/\/git@github\.com\/|git@github\.com:|github:)?([^/\s]+)\/([^/\s]+)$/i
  )

  if (!match) return ''
  return `${match[1]}/${match[2]}`
}

function hasAll(env, names) {
  return names.every(name => normalizeText(env[name]).length > 0)
}

function evaluateLocalSecrets(env = process.env) {
  const macCertificate = hasAll(env, ['CSC_LINK', 'CSC_KEY_PASSWORD'])
  const windowsCertificate = hasAll(env, ['WIN_CSC_LINK', 'WIN_CSC_KEY_PASSWORD']) || macCertificate
  const macNotarization =
    hasAll(env, ['APPLE_API_KEY', 'APPLE_API_KEY_ID', 'APPLE_API_ISSUER']) ||
    hasAll(env, ['APPLE_ID', 'APPLE_APP_SPECIFIC_PASSWORD', 'APPLE_TEAM_ID']) ||
    hasAll(env, ['APPLE_KEYCHAIN', 'APPLE_KEYCHAIN_PROFILE'])

  return {
    macCertificate,
    windowsCertificate,
    macNotarization
  }
}

async function evaluateBuildAssets(rootDir = projectRoot) {
  const results = await Promise.all(
    REQUIRED_ASSETS.map(async relativePath => {
      try {
        await fs.access(path.join(rootDir, relativePath))
        return { path: relativePath, present: true }
      } catch {
        return { path: relativePath, present: false }
      }
    })
  )

  return {
    ok: results.every(item => item.present),
    items: results
  }
}

function listGitHubSecrets(repositorySlug) {
  if (!repositorySlug) {
    return {
      ok: false,
      available: [],
      reason: '未解析到 GitHub 仓库地址。'
    }
  }

  const result = spawnSync('gh', ['secret', 'list', '-R', repositorySlug], {
    cwd: projectRoot,
    encoding: 'utf-8'
  })

  if (result.error) {
    return {
      ok: false,
      available: [],
      reason: result.error.message || '无法调用 gh secret list。'
    }
  }

  if (result.status !== 0) {
    return {
      ok: false,
      available: [],
      reason: normalizeText(result.stderr || result.stdout, 'gh secret list 执行失败。')
    }
  }

  const secretNames = result.stdout
    .split(/\r?\n/)
    .map(line => line.trim().split(/\s+/)[0])
    .filter(Boolean)

  return {
    ok: true,
    available: secretNames,
    reason: ''
  }
}

function evaluateGitHubSecrets(availableSecretNames = []) {
  const secretSet = new Set(availableSecretNames.map(item => normalizeText(item)))
  const macCertificate = secretSet.has('CSC_LINK') && secretSet.has('CSC_KEY_PASSWORD')
  const windowsCertificate =
    (secretSet.has('WIN_CSC_LINK') && secretSet.has('WIN_CSC_KEY_PASSWORD')) ||
    (secretSet.has('CSC_LINK') && secretSet.has('CSC_KEY_PASSWORD'))
  const macNotarization =
    (secretSet.has('APPLE_API_KEY') && secretSet.has('APPLE_API_KEY_ID') && secretSet.has('APPLE_API_ISSUER')) ||
    (secretSet.has('APPLE_ID') && secretSet.has('APPLE_APP_SPECIFIC_PASSWORD') && secretSet.has('APPLE_TEAM_ID')) ||
    (secretSet.has('APPLE_KEYCHAIN') && secretSet.has('APPLE_KEYCHAIN_PROFILE'))

  return {
    macCertificate,
    windowsCertificate,
    macNotarization,
    missingRecommended: GITHUB_SECRET_NAMES.filter(item => !secretSet.has(item))
  }
}

function printSection(title, lines) {
  process.stdout.write(`${title}\n`)
  for (const line of lines) {
    process.stdout.write(`- ${line}\n`)
  }
  process.stdout.write('\n')
}

async function main() {
  const options = parseArgs(process.argv.slice(2))
  const packageManifest = JSON.parse(await fs.readFile(path.join(projectRoot, 'package.json'), 'utf-8'))
  const repositorySlug = parseRepositorySlug(packageManifest.repository)
  const assets = await evaluateBuildAssets(projectRoot)
  const localSecrets = evaluateLocalSecrets(process.env)
  const githubSecretsResult = options.noGithub
    ? { ok: false, available: [], reason: '已跳过 GitHub secrets 检查。' }
    : listGitHubSecrets(repositorySlug)
  const githubSecrets = evaluateGitHubSecrets(githubSecretsResult.available)

  const summary = {
    repository: repositorySlug,
    version: normalizeText(packageManifest.version, '0.0.0'),
    releaseChannel: 'stable',
    assets,
    localSecrets,
    githubSecretsResult,
    githubSecrets
  }

  if (options.json) {
    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`)
  } else {
    printSection('WordZ Release Doctor', [
      `仓库：${repositorySlug || '未配置'}`,
      `版本：${summary.version}`,
      '发布渠道：稳定版'
    ])

    printSection('构建资源', summary.assets.items.map(item => `${item.present ? '已就绪' : '缺失'} ${item.path}`))

    printSection('本地签名环境', [
      `macOS 证书：${localSecrets.macCertificate ? '已就绪' : '未配置'}`,
      `Windows 证书：${localSecrets.windowsCertificate ? '已就绪' : '未配置'}`,
      `macOS notarization：${localSecrets.macNotarization ? '已就绪' : '未配置'}`
    ])

    if (githubSecretsResult.ok) {
      printSection('GitHub Secrets', [
        `已配置数量：${githubSecretsResult.available.length}`,
        `macOS 证书：${githubSecrets.macCertificate ? '已就绪' : '未配置'}`,
        `Windows 证书：${githubSecrets.windowsCertificate ? '已就绪' : '未配置'}`,
        `macOS notarization：${githubSecrets.macNotarization ? '已就绪' : '未配置'}`,
        githubSecrets.missingRecommended.length > 0
          ? `建议补齐：${githubSecrets.missingRecommended.join(', ')}`
          : '推荐 secrets 已全部存在。'
      ])
    } else {
      printSection('GitHub Secrets', [githubSecretsResult.reason])
    }
  }

  if (
    options.strict &&
    (!assets.ok || !localSecrets.windowsCertificate || !localSecrets.macCertificate || !localSecrets.macNotarization)
  ) {
    process.exitCode = 1
  }
}

main().catch(error => {
  console.error('[release-doctor]', error)
  process.exit(1)
})

export {
  parseRepositorySlug,
  evaluateLocalSecrets,
  evaluateGitHubSecrets
}
