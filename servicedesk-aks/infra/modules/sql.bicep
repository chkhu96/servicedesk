param location string
param name string
param adminLogin string
@secure()
param adminPassword string
param entraAdminObjectId string
param entraAdminLogin string
param peSubnetId string
param dnsZoneId string
param dbName string = 'servicedesk'

resource sql 'Microsoft.Sql/servers@2021-11-01' = {
  name: name
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
    administrators: {
      administratorType: 'ActiveDirectory'
      login: entraAdminLogin
      sid: entraAdminObjectId
      tenantId: tenant().tenantId
      principalType: 'User'
      azureADOnlyAuthentication: false // set true in the passwordless phase
    }
  }
}

resource db 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sql
  name: dbName
  location: location
  sku: {
    name: 'GP_S_Gen5_1'
    tier: 'GeneralPurpose'
  }
  properties: {
    autoPauseDelay: 60
    minCapacity: json('0.5')
    maxSizeBytes: 2147483648
  }
}

module pe 'private-endpoint.bicep' = {
  name: 'pe-sql'
  params: {
    location: location
    name: '${name}-pe'
    subnetId: peSubnetId
    targetId: sql.id
    groupId: 'sqlServer'
    dnsZoneId: dnsZoneId
  }
}

output fqdn string = sql.properties.fullyQualifiedDomainName
output dbName string = db.name
