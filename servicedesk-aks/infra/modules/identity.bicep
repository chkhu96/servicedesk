// AKS control plane identity + Network Contributor on the VNet (needed for internal LB on BYO VNet)
param location string
param prefix string
param vnetName string

resource cpId 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-aks-cp-id'
  location: location
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}

var networkContributor = '4d97b98b-1d4f-4787-a291-c67834d212e7'

resource ra 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet.id, cpId.id, networkContributor)
  scope: vnet
  properties: {
    principalId: cpId.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', networkContributor)
  }
}

output controlPlaneIdentityId string = cpId.id
