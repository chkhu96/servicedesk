param location string
param prefix string
param jumpboxSubnetId string
param bastionSubnetId string
param sshPublicKey string
param vmSize string = 'Standard_D2alds_v6'

var cloudInit = loadTextContent('../cloud-init-jumpbox.yaml')

resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${prefix}-bastion-pip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: '${prefix}-bastion'
  location: location
  sku: { name: 'Standard' }
  properties: {
    enableTunneling: true // allows 'az network bastion ssh/tunnel' from your laptop (and scp via tunnel)
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: { id: bastionSubnetId }
          publicIPAddress: { id: bastionPip.id }
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${prefix}-jumpbox-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: { id: jumpboxSubnetId }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: '${prefix}-jumpbox'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: 'jumpbox'
      adminUsername: 'azureuser'
      customData: base64(cloudInit)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/azureuser/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
        diskSizeGB: 64
      }
    }
    networkProfile: { networkInterfaces: [ { id: nic.id } ] }
  }
}

output bastionName string = bastion.name
output vmId string = vm.id
