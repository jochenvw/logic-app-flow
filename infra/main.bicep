var resourceNamePrefix = 'logicapp-flow'
var resourceLocation = 'westeurope'

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${resourceNamePrefix}-logs'
  location: resourceLocation
}

resource appserviceplan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: '${resourceNamePrefix}-host'
  location: resourceLocation
  kind: 'elastic'
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
    size: 'WS1'
    family: 'WS'
    capacity: 1
  }
}

resource azureLoadBalancerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appserviceplan
  name: '${resourceNamePrefix}-host-diagnostics'
  properties: {
    'workspaceId': workspace.id
    logs: [
    ]    
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
