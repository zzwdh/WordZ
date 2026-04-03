import { spawn } from 'node:child_process'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const SIGNING_ENV_KEYS = [
  'CSC_LINK',
  'CSC_KEY_PASSWORD',
  'CSC_NAME',
  'APPLE_API_KEY',
  'APPLE_API_KEY_ID',
  'APPLE_API_ISSUER',
  'APPLE_ID',
  'APPLE_APP_SPECIFIC_PASSWORD',
  'APPLE_TEAM_ID',
  'APPLE_KEYCHAIN',
  'APPLE_KEYCHAIN_PROFILE',
  'WIN_CSC_LINK',
  'WIN_CSC_KEY_PASSWORD'
]

export function normalizeText(value) {
  return String(value || '').trim()
}

export function normalizeBoolean(value, fallbackValue = false) {
  if (value === undefined || value === null || value === '') return fallbackValue
  const normalizedValue = String(value).trim().toLowerCase()
  if (['1', 'true', 'yes', 'on'].includes(normalizedValue)) return true
  if (['0', 'false', 'no', 'off'].includes(normalizedValue)) return false
  return fallbackValue
}

export function resolveGitHubRepo(env) {
  const repositorySlug = normalizeText(env.GITHUB_REPOSITORY)
  const repositoryParts = repositorySlug.includes('/') ? repositorySlug.split('/') : []
  const owner =
    normalizeText(env.WORDZ_AUTO_UPDATE_GITHUB_OWNER) ||
    normalizeText(env.WORDZ_GH_OWNER) ||
    normalizeText(env.GITHUB_REPOSITORY_OWNER) ||
    normalizeText(repositoryParts[0])
  const repo =
    normalizeText(env.WORDZ_AUTO_UPDATE_GITHUB_REPO) ||
    normalizeText(env.WORDZ_GH_REPO) ||
    normalizeText(repositoryParts[1])

  return {
    owner,
    repo
  }
}

export function buildElectronBuilderArgs({ extraArgs = [], owner, repo, isPrivateRepo = false }) {
  return [
    '--publish',
    'always',
    ...extraArgs,
    '-c.extraMetadata.wordz.release.channel=stable',
    '-c.extraMetadata.wordz.autoUpdate.provider=github',
    '-c.extraMetadata.wordz.autoUpdate.channel=latest',
    '-c.extraMetadata.wordz.autoUpdate.allowPrerelease=false',
    `-c.extraMetadata.wordz.autoUpdate.github.owner=${owner}`,
    `-c.extraMetadata.wordz.autoUpdate.github.repo=${repo}`,
    `-c.extraMetadata.wordz.autoUpdate.github.private=${isPrivateRepo ? 'true' : 'false'}`
  ]
}

export function buildPublishEnvironment(baseEnv, githubToken) {
  const nextEnv = {
    ...baseEnv,
    GH_TOKEN: githubToken
  }

  for (const key of SIGNING_ENV_KEYS) {
    if (!normalizeText(nextEnv[key])) {
      delete nextEnv[key]
    }
  }

  return nextEnv
}

export function resolveGitHubReleaseConfig(env = process.env, argv = process.argv.slice(2)) {
  if (argv.includes('--mac')) {
    throw new Error('Electron macOS 发布链已退役，请改用 npm run native:mac:package 并上传原生 macOS 产物。')
  }

  const { owner, repo } = resolveGitHubRepo(env)
  if (!owner || !repo) {
    throw new Error('缺少 GitHub 仓库信息，请设置 WORDZ_AUTO_UPDATE_GITHUB_OWNER/REPO 或 GITHUB_REPOSITORY。')
  }

  const githubToken = normalizeText(env.GH_TOKEN) || normalizeText(env.GITHUB_TOKEN)
  if (!githubToken) {
    throw new Error('缺少 GH_TOKEN 或 GITHUB_TOKEN，无法发布到 GitHub Releases。')
  }

  const isPrivateRepo = normalizeBoolean(
    env.WORDZ_AUTO_UPDATE_GITHUB_PRIVATE || env.WORDZ_GH_PRIVATE,
    false
  )

  const command = process.platform === 'win32'
    ? path.join(process.cwd(), 'node_modules', '.bin', 'electron-builder.cmd')
    : path.join(process.cwd(), 'node_modules', '.bin', 'electron-builder')

  return {
    owner,
    repo,
    githubToken,
    isPrivateRepo,
    command,
    electronBuilderArgs: buildElectronBuilderArgs({
      extraArgs: argv,
      owner,
      repo,
      isPrivateRepo
    }),
    childEnv: buildPublishEnvironment(env, githubToken)
  }
}

export function runGitHubRelease(env = process.env, argv = process.argv.slice(2)) {
  const config = resolveGitHubReleaseConfig(env, argv)

  console.log(`[github-release] publishing WordZ stable release to GitHub Releases: ${config.owner}/${config.repo}`)

  const child = spawn(config.command, config.electronBuilderArgs, {
    stdio: 'inherit',
    shell: process.platform === 'win32',
    env: config.childEnv
  })

  child.on('error', error => {
    console.error('[github-release] 启动 electron-builder 失败。')
    console.error(error)
    process.exit(1)
  })

  child.on('exit', code => {
    process.exit(code ?? 1)
  })

  return child
}

const executedPath = process.argv[1] ? path.resolve(process.argv[1]) : ''
const isDirectExecution = executedPath === path.resolve(fileURLToPath(import.meta.url))

if (isDirectExecution) {
  try {
    runGitHubRelease()
  } catch (error) {
    console.error(`[github-release] ${error instanceof Error ? error.message : String(error)}`)
    process.exit(1)
  }
}
