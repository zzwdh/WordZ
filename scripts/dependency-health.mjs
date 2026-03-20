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
  return stdout ? JSON.parse(stdout) : {}
}

function printHeading(title) {
  console.log(`\n=== ${title} ===`)
}

function printOutdatedSummary(outdatedPackages) {
  const packageNames = Object.keys(outdatedPackages)
  if (packageNames.length === 0) {
    console.log('依赖已是最新可用版本。')
    return false
  }

  console.log(`发现 ${packageNames.length} 个可升级依赖：`)
  for (const packageName of packageNames.sort()) {
    const info = outdatedPackages[packageName] || {}
    console.log(`- ${packageName}: current=${info.current} wanted=${info.wanted} latest=${info.latest}`)
  }
  return true
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
const hasOutdatedPackages = printOutdatedSummary(outdatedPackages)

printHeading('Audit')
const auditReport = runJsonNpmCommand(['audit', '--json'], [0, 1])
const hasAuditIssues = printAuditSummary(auditReport)

printHeading('Result')
if (!hasOutdatedPackages && !hasAuditIssues) {
  console.log('依赖状态健康。')
  process.exit(0)
}

console.log('依赖巡检未通过，请处理上面的升级或安全问题。')
process.exit(1)
