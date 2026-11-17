param location string
param vnetName string
param prefix string

// Jumpbox needs outbound internet (apt, docker hub, pip). New VNets have no default outbound access.
resource natPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${prefix}-nat-pip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource nat 'Microsoft.Network/natGateways@2023-11-01' = {
  name: '${prefix}-nat'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIpAddresses: [ { id: natPip.id } ] }
}

resource nsgJump 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${prefix}-nsg-jumpbox'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-Bastion'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.6.0/26'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.10.0.0/16' ] }
    subnets: [
      {
        name: 'snet-aks'
        properties: { addressPrefix: '10.10.0.0/22' }
      }
      {
        name: 'snet-pe'
        properties: {
          addressPrefix: '10.10.4.0/27'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-jumpbox'
        properties: {
          addressPrefix: '10.10.5.0/28'
          natGateway: { id: nat.id }
          networkSecurityGroup: { id: nsgJump.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: { addressPrefix: '10.10.6.0/26' }
      }
    ]
  }
}

output vnetId string = vnet.id
output aksSubnetId string = '${vnet.id}/subnets/snet-aks'
output peSubnetId string = '${vnet.id}/subnets/snet-pe'
output jumpboxSubnetId string = '${vnet.id}/subnets/snet-jumpbox'
output bastionSubnetId string = '${vnet.id}/subnets/AzureBastionSubnet'
