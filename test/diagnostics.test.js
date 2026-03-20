const test = require('node:test')
const assert = require('node:assert/strict')

const { buildGitHubIssueUrl, renderDiagnosticReport } = require('../diagnostics')

test('buildGitHubIssueUrl creates a prefilled GitHub issue link from repository metadata', () => {
  const url = buildGitHubIssueUrl({
    packageManifest: {
      name: 'corpus-lite',
      productName: 'WordZ',
      version: '1.0.2',
      repository: {
        type: 'git',
        url: 'https://github.com/zzwdh/WordZ.git'
      }
    },
    appInfo: {
      name: 'WordZ',
      version: '1.0.2'
    },
    snapshot: {
      sessionId: '20260320T120000Z',
      platform: 'darwin',
      arch: 'arm64',
      debugLoggingEnabled: true,
      recentErrors: [
        {
          timestamp: '2026-03-20T12:00:00.000Z',
          level: 'error',
          scope: 'analysis.stats',
          message: '统计失败'
        }
      ]
    },
    rendererState: {
      currentTab: 'stats',
      corpusDisplayName: 'demo'
    },
    issueTitle: '[Bug] 统计失败'
  })
  const parsedUrl = new URL(url)
  const issueTitle = parsedUrl.searchParams.get('title') || ''
  const issueBody = parsedUrl.searchParams.get('body') || ''

  assert.match(url, /^https:\/\/github\.com\/zzwdh\/WordZ\/issues\/new\?/)
  assert.equal(issueTitle, '[Bug] 统计失败')
  assert.match(issueBody, /会话 ID：20260320T120000Z/)
  assert.match(issueBody, /"currentTab": "stats"/)
})

test('renderDiagnosticReport includes environment, state and recent errors', () => {
  const report = renderDiagnosticReport({
    packageManifest: {
      productName: 'WordZ',
      version: '1.0.2'
    },
    appInfo: {
      name: 'WordZ',
      version: '1.0.2',
      help: ['使用设置中的诊断与反馈导出诊断报告。']
    },
    snapshot: {
      sessionId: '20260320T120000Z',
      platform: 'darwin',
      arch: 'arm64',
      nodeVersion: '24.14.0',
      electronVersion: '41.0.3',
      debugLoggingEnabled: true,
      logFilePath: '/tmp/wordz.log',
      lastExportPath: '/tmp/wordz-report.md',
      recentErrors: [
        {
          timestamp: '2026-03-20T12:00:00.000Z',
          level: 'error',
          scope: 'renderer.error',
          message: '未捕获错误'
        }
      ],
      recentEvents: [
        {
          timestamp: '2026-03-20T12:00:01.000Z',
          level: 'info',
          scope: 'analysis.stats',
          message: '统计任务完成'
        }
      ]
    },
    rendererState: {
      currentTab: 'kwic',
      corpusDisplayName: 'demo'
    }
  })

  assert.match(report, /# WordZ 诊断报告/)
  assert.match(report, /## 应用环境/)
  assert.match(report, /调试日志：已开启/)
  assert.match(report, /## 当前工作区摘要/)
  assert.match(report, /"currentTab": "kwic"/)
  assert.match(report, /## 最近错误/)
  assert.match(report, /renderer\.error/)
  assert.match(report, /## 帮助信息/)
})
