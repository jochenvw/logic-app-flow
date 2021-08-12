var resourceNamePrefix = 'logicapp-flow'
var resourceNameSuffix = '-dev'
var resourceLocation = 'westeurope'

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${resourceNamePrefix}-logs-${resourceNameSuffix}'
  location: resourceLocation
}

resource appserviceplan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: '${resourceNamePrefix}-host-${resourceNameSuffix}'
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
  name: '${resourceNamePrefix}-host-diagnostics-${resourceNameSuffix}'
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
  name: '${resourceNamePrefix}-insights-${resourceNameSuffix}'
  location: resourceLocation  
  kind: 'web'
  properties: {
    WorkspaceResourceId: workspace.id
    Application_Type: 'web'
  }
}

resource flow 'Microsoft.Web/sites@2021-01-15' = {
  name: '${resourceNamePrefix}-flows-${resourceNameSuffix}'
  location: resourceLocation
  kind: 'functionapp,workflowapp'  
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~12'
        }
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
          value:'${toLower('${resourceNamePrefix}-flows')}8992'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }        
      ]
    }
  }
}

resource appstorage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: replace('${resourceNamePrefix}-host-store-${resourceNameSuffix}','-','')
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

resource storage_blob_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${flowexchangestorage.name}/default/out'
  properties: {
    publicAccess: 'None'
  }
}

var blobContributorGuid = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
resource symbolicname 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = {
  name: guid(flow.id, blobContributorGuid)
  scope: storage_blob_container    
  properties: {                
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', blobContributorGuid)
    principalId: flow.identity.principalId
  }
}


resource flowexchangestorage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: replace('${resourceNamePrefix}-app-store-${resourceNameSuffix}','-','')
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