const { createAppBridge } = require('./bridges/appBridge')
const { createDiagnosticsBridge } = require('./bridges/diagnosticsBridge')
const { createLibraryBridge } = require('./bridges/libraryBridge')
const { createWindowBridge } = require('./bridges/windowBridge')
const { createUpdateBridge } = require('./bridges/updateBridge')
const { createSmokeBridge } = require('./bridges/smokeBridge')

const DEFAULT_BRIDGE_FACTORIES = Object.freeze([
  { name: 'appBridge', factory: createAppBridge },
  { name: 'diagnosticsBridge', factory: createDiagnosticsBridge },
  { name: 'libraryBridge', factory: createLibraryBridge },
  { name: 'windowBridge', factory: createWindowBridge },
  { name: 'updateBridge', factory: createUpdateBridge },
  { name: 'smokeBridge', factory: createSmokeBridge }
])

module.exports = {
  DEFAULT_BRIDGE_FACTORIES
}
