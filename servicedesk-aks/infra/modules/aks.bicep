param location string
param name string
param kubernetesVersion string
param aksSubnetId string
param controlPlaneIdentityId string
param lawId string

resource aks 'Microsoft.ContainerService/managedClusters@2024-05-01' = {
  name: name
  location: location
  sku: { name: 'Base', tier: 'Free' }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${controlPlaneIdentityId}': {} }
  }
  properties: {
    kubernetesVersion: empty(kubernetesVersion) ? null : kubernetesVersion
    dnsPrefix: name
    nodeResourceGroup: '${resourceGroup().name}-nodes'
    enableRBAC: true
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: 'system' // AKS creates privatelink.<region>.azmk8s.io in the node RG, linked to this VNet
      enablePrivateClusterPublicFQDN: false
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      podCidr: '192.168.0.0/16'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
      outboundType: 'loadBalancer'
    }
    oidcIssuerProfile: { enabled: true }
    securityProfile: {
      workloadIdentity: { enabled: true }
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: { enableSecretRotation: 'true', rotationPollInterval: '2m' }
      }
      omsagent: {
        enabled: true
        config: { logAnalyticsWorkspaceResourceID: lawId }
      }
    }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: 1
        vmSize: 'Standard_D2s_v5'
        osType: 'Linux'
        vnetSubnetID: aksSubnetId
        nodeTaints: [ 'CriticalAddonsOnly=true:NoSchedule' ]
      }
      {
        name: 'user'
        mode: 'User'
        count: 1
        minCount: 1
        maxCount: 3
        enableAutoScaling: true
        vmSize: 'Standard_D4s_v5'
        osType: 'Linux'
        vnetSubnetID: aksSubnetId
      }
    ]
  }
}

output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
output kubeletObjectId string = aks.properties.identityProfile.kubeletidentity.objectId
