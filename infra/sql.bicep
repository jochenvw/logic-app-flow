/*
BIICEP - convert to JSON and use in LogicApp
*/

var resourceNamePrefix = 'logicapp-flow'

resource server 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: '${resourceNamePrefix}-managed-sql-server'
  location: 'westeurope'
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      login: '[admin]'
      sid: '[admin-sid]'
      tenantId: '[tenantid]'
      principalType: 'User'
      azureADOnlyAuthentication: true
    }
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: '${server.name}/DB1'
  location: 'westeurope'  
  properties: {    
  }  
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}
