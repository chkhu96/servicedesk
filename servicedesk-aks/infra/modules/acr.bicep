param location string
param name string
param peSubnetId string
param dnsZoneId string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  sku: { name: 'Premium' } // Premium is required for private endpoints
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

module pe 'private-endpoint.bicep' = {
  name: 'pe-acr'
  params: {
    location: location
    name: '${name}-pe'
    subnetId: peSubnetId
    targetId: acr.id
    groupId: 'registry' // creates both registry and regional data endpoint records
    dnsZoneId: dnsZoneId
  }
}

output loginServer string = acr.properties.loginServer
