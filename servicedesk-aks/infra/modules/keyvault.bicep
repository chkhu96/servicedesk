param location string
param name string
param peSubnetId string
param dnsZoneId string
@secure()
param sqlConnectionString string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', bypass: 'AzureServices' }
  }
}

// Secrets created via ARM (control plane) - works even with public access disabled
resource sqlConn 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'sql-connection-string'
  properties: { value: sqlConnectionString }
}

resource slaConfig 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'sla-config'
  properties: {
    value: '{"P1":4,"P2":8,"P3":24,"P4":72}'
    contentType: 'application/json'
  }
}

module pe 'private-endpoint.bicep' = {
  name: 'pe-kv'
  params: {
    location: location
    name: '${name}-pe'
    subnetId: peSubnetId
    targetId: kv.id
    groupId: 'vault'
    dnsZoneId: dnsZoneId
  }
}
