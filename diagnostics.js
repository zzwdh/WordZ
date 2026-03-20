const { createDiagnosticsController } = require('./diagnostics/controller')
const {
  buildGitHubIssueUrl,
  parseGitHubRepository,
  renderDiagnosticReport
} = require('./diagnostics/format')

module.exports = {
  buildGitHubIssueUrl,
  createDiagnosticsController,
  parseGitHubRepository,
  renderDiagnosticReport
}
