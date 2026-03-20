import { spawn } from 'node:child_process'
import path from 'node:path'
import process from 'node:process'

function normalizeText(value) {
  return String(value || '').trim()
}

function normalizeBoolean(value, fallbackValue = false) {
  if (value === undefined || value === null || value === '') return fallbackValue
  const normalizedValue = String(value).trim().toLowerCase()
  if (['1', 'true', 'yes', 'on'].includes(normalizedValue)) return true
  if (['0', 'false', 'no', 'off'].includes(normalizedValue)) return false
  return fallbackValue
}

function resolveGitHubRepo(env) {
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

const { owner, repo } = resolveGitHubRepo(process.env)
if (!owner || !repo) {
  console.error('[github-release] 缺少 GitHub 仓库信息，请设置 WORDZ_AUTO_UPDATE_GITHUB_OWNER/REPO 或 GITHUB_REPOSITORY。')
  process.exit(1)
}

const githubToken = normalizeText(process.env.GH_TOKEN) || normalizeText(process.env.GITHUB_TOKEN)
if (!githubToken) {
  console.error('[github-release] 缺少 GH_TOKEN 或 GITHUB_TOKEN，无法发布到 GitHub Releases。')
  process.exit(1)
}

const isPrivateRepo = normalizeBoolean(
  process.env.WORDZ_AUTO_UPDATE_GITHUB_PRIVATE || process.env.WORDZ_GH_PRIVATE,
  false
)
const releaseChannel = 'stable'
const extraArgs = process.argv.slice(2)
const electronBuilderArgs = [
  '--publish',
  'always',
  ...extraArgs,
  `-c.extraMetadata.wordz.release.channel=${releaseChannel}`,
  '-c.extraMetadata.wordz.autoUpdate.provider=github',
  '-c.extraMetadata.wordz.autoUpdate.channel=latest',
  '-c.extraMetadata.wordz.autoUpdate.allowPrerelease=false',
  `-c.extraMetadata.wordz.autoUpdate.github.owner=${owner}`,
  `-c.extraMetadata.wordz.autoUpdate.github.repo=${repo}`,
  `-c.extraMetadata.wordz.autoUpdate.github.private=${isPrivateRepo ? 'true' : 'false'}`
]
const command = process.platform === 'win32'
  ? path.join(process.cwd(), 'node_modules', '.bin', 'electron-builder.cmd')
  : path.join(process.cwd(), 'node_modules', '.bin', 'electron-builder')

console.log(`[github-release] publishing WordZ stable release to GitHub Releases: ${owner}/${repo}`)

const child = spawn(command, electronBuilderArgs, {
  stdio: 'inherit',
  shell: process.platform === 'win32',
  env: {
    ...process.env,
    GH_TOKEN: githubToken
  }
})

child.on('error', error => {
  console.error('[github-release] 启动 electron-builder 失败。')
  console.error(error)
  process.exit(1)
})

child.on('exit', code => {
  process.exit(code ?? 1)
})
