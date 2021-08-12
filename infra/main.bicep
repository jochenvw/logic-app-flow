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

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${resourceNamePrefix}-insights'
  location: resourceLocation  
  kind: 'web'
  properties: {
    WorkspaceResourceId: workspace.id
    Application_Type: 'web'
  }
}

resource flow 'Microsoft.Web/sites@2021-01-15' = {
  name: '${resourceNamePrefix}-flows'
  location: resourceLocation
  kind: 'functionapp,workflowapp'  
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appinsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appinsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${appstorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(appstorage.id, appstorage.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${appstorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(appstorage.id, appstorage.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: 'logicappshare'
        }
      ]
    }
  }
}

resource appstorage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: replace('${resourceNamePrefix}-host-store','-','')
  location: resourceLocation
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource flowexchangestorage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: replace('${resourceNamePrefix}-app-store','-','')
  kind: 'StorageV2'
  location: resourceLocation
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}
