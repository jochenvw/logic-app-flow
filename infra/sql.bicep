/*
BIICEP - convert to JSON and use in LogicApp
*/
param servername string = ''
param dbname string = ''
param location string = ''
var resourceNamePrefix = 'logicapp-flow'

resource server 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: '${resourceNamePrefix}-managed-sql-server-${servername}'
  location: location
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
  name: '${server.name}/${dbname}'
  location: location  
  properties: {    
  }  
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}
