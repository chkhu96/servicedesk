param vnetId string

var zones = [
  'privatelink.azurecr.io'
  'privatelink.database.windows.net'
  'privatelink.vaultcore.azure.net'
  'lab.internal' // custom zone for the app hostname
]

resource zone 'Microsoft.Network/privateDnsZones@2020-06-01' = [for z in zones: {
  name: z
  location: 'global'
}]

resource link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (z, i) in zones: {
  parent: zone[i]
  name: 'link-lab-vnet'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnetId }
  }
}]

output acrZoneId string = zone[0].id
output sqlZoneId string = zone[1].id
output kvZoneId string = zone[2].id
output appZoneName string = zone[3].name
