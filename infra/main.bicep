param serverName string = uniqueString('sqlserverrabo', resourceGroup().id)
param sqlDBName string = 'newdatabase'
param resourceLocation string = resourceGroup().location
param administratorLogin string

@secure()
param administratorLoginPassword string

var resourceNamePrefix = 'logicapp-flow'
var resourceNameSuffix = '-dev'


// ----------------- AppService --------------- //

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

// ----------------- Insights --------------- //

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${resourceNamePrefix}-logs-${resourceNameSuffix}'
  location: resourceLocation
}

resource azureLoadBalancerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appserviceplan
  name: '${resourceNamePrefix}-host-diagnostics-${resourceNameSuffix}'
  properties: {
    'workspaceId': workspace.id
    logs: []
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

// ----------------- Storage + Container --------------- //

resource flowexchangestorage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: replace('${resourceNamePrefix}-app-store-${resourceNameSuffix}', '-', '')
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

resource appstorage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: replace('${resourceNamePrefix}-host-store-${resourceNameSuffix}', '-', '')
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

// ----------------- SQL Server + DB --------------- //

resource server 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: serverName
  location: resourceLocation
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2020-08-01-preview' = {
  name: '${server.name}/${sqlDBName}'
  location: resourceLocation
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}


// ----------------- Logic App + Workflow --------------- //

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
          value: '${toLower('${resourceNamePrefix}-flows')}8992'
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

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'workflow-from-bicep'
  location: resourceLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      actions: {
        'HTTP': {
          'inputs': {
            'authentication': {
              'audience': 'https://storage.azure.com/'
              'type': 'ManagedServiceIdentity'
            }
            'body': '@triggerBody()'
            'headers': {
              'Content-length': '@{length(string(triggerBody()))}'
              'x-ms-version': '2019-02-02'
              'x-ms-blob-type': 'BlockBlob'
            }
            'method': 'PUT'
            'uri': 'https://logicappflowappstoredev.blob.core.windows.net/out/myblob.json'
          }
          'runAfter': {}
          'type': 'Http'
        }
      }
      'contentVersion': '1.0.0.0'
      'outputs': {}
      'triggers': {
        'manual': {
          'inputs': {}
          'kind': 'Http'
          'type': 'Request'
        }
      }
    }
  }
}


// ----------------- Role Assignments --------------- //

var blobContributorGuid = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
resource blobContribRoleAssign 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = {
  name: guid(workflow.id, blobContributorGuid)
  scope: storage_blob_container
  properties: {
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', blobContributorGuid)
    principalId: workflow.identity.principalId
  }
}

var sqlServerContributor = '6d8ee4ec-f05a-4a1d-8b00-a9b17e38b437'
resource sqlContribRoleAssignment 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = {
  name: guid(workflow.id, sqlServerContributor)
  scope: server    
  properties: {                
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', sqlServerContributor)
    principalId: workflow.identity.principalId
  }
}
