import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(__dirname, '..')
const packageJson = JSON.parse(fs.readFileSync(path.join(projectRoot, 'package.json'), 'utf-8'))
const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm'

function runJsonNpmCommand(args, allowedExitCodes) {
  const result = spawnSync(npmCommand, args, {
    cwd: projectRoot,
    encoding: 'utf-8',
    env: process.env
  })

  if (!allowedExitCodes.includes(result.status ?? 0)) {
    const stderr = result.stderr?.trim()
    throw new Error(`${npmCommand} ${args.join(' ')} 执行失败${stderr ? `: ${stderr}` : ''}`)
  }

  const stdout = (result.stdout || '').trim()
  if (!stdout) return {}

  try {
    return JSON.parse(stdout)
  } catch {
    const firstBrace = stdout.indexOf('{')
    const lastBrace = stdout.lastIndexOf('}')
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      const maybeJson = stdout.slice(firstBrace, lastBrace + 1)
      try {
        return JSON.parse(maybeJson)
      } catch {
        // ignore and throw below
      }
    }
    throw new Error(`${npmCommand} ${args.join(' ')} 输出不是有效 JSON`)
  }
}

function printHeading(title) {
  console.log(`\n=== ${title} ===`)
}

function normalizeOutdatedPackages(rawOutdatedPackages) {
  const normalizedPackages = {}
  const diagnostics = []

  if (!rawOutdatedPackages || typeof rawOutdatedPackages !== 'object') {
    return {
      packages: normalizedPackages,
      diagnostics
    }
  }

  for (const [name, info] of Object.entries(rawOutdatedPackages)) {
    if (!info || typeof info !== 'object' || Array.isArray(info)) {
      if (name === 'error' || name === 'message') {
        diagnostics.push(`${name}: ${String(info)}`)
      }
      continue
    }

    const hasVersionShape = 'current' in info || 'wanted' in info || 'latest' in info
    if (hasVersionShape) {
      normalizedPackages[name] = info
      continue
    }

    if ('code' in info || 'summary' in info || 'detail' in info) {
      diagnostics.push(`${name}: ${JSON.stringify(info)}`)
    }
  }

  return {
    packages: normalizedPackages,
    diagnostics
  }
}

function printOutdatedSummary(rawOutdatedPackages) {
  const { packages: outdatedPackages, diagnostics } = normalizeOutdatedPackages(rawOutdatedPackages)
  const packageNames = Object.keys(outdatedPackages)

  if (diagnostics.length > 0) {
    console.log('依赖更新检查返回了异常信息：')
    for (const line of diagnostics) {
      console.log(`- ${line}`)
    }
  }

  if (packageNames.length === 0) {
    console.log('依赖已是最新可用版本。')
    return {
      hasOutdatedPackages: false,
      hasCheckErrors: diagnostics.length > 0
    }
  }

  console.log(`发现 ${packageNames.length} 个可升级依赖：`)
  for (const packageName of packageNames.sort()) {
    const info = outdatedPackages[packageName] || {}
    console.log(`- ${packageName}: current=${info.current} wanted=${info.wanted} latest=${info.latest}`)
  }
  return {
    hasOutdatedPackages: true,
    hasCheckErrors: diagnostics.length > 0
  }
}

function printAuditSummary(auditReport) {
  const vulnerabilityTotals = auditReport?.metadata?.vulnerabilities || {}
  const totalVulnerabilities = vulnerabilityTotals.total || 0

  if (totalVulnerabilities === 0) {
    console.log('未发现审计漏洞。')
    return false
  }

  console.log(`发现 ${totalVulnerabilities} 个漏洞：`)
  for (const [packageName, info] of Object.entries(auditReport.vulnerabilities || {})) {
    console.log(`- ${packageName}: severity=${info.severity}`)
  }
  return true
}

console.log('依赖巡检开始')
console.log(`packageManager: ${packageJson.packageManager || '未设置'}`)
console.log(`engines.node: ${packageJson.engines?.node || '未设置'}`)
console.log(`engines.npm: ${packageJson.engines?.npm || '未设置'}`)

printHeading('Outdated')
const outdatedPackages = runJsonNpmCommand(['outdated', '--json'], [0, 1])
const {
  hasOutdatedPackages,
  hasCheckErrors: hasOutdatedCheckErrors
} = printOutdatedSummary(outdatedPackages)

printHeading('Audit')
const auditReport = runJsonNpmCommand(['audit', '--json'], [0, 1])
const hasAuditIssues = printAuditSummary(auditReport)

printHeading('Result')
if (!hasOutdatedPackages && !hasAuditIssues && !hasOutdatedCheckErrors) {
  console.log('依赖状态健康。')
  process.exit(0)
}

if (hasOutdatedCheckErrors) {
  console.log('依赖更新检查存在异常，请先修复网络或 registry 配置后再重试。')
}
console.log('依赖巡检未通过，请处理上面的升级或安全问题。')
process.exit(1)
