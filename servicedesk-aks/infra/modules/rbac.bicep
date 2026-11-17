param acrName string
param kvName string
param aksName string
param kubeletObjectId string
param workloadPrincipalId string
param deployerObjectId string

var roles = {
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  acrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
  kvSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  kvAdmin: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  aksRbacClusterAdmin: 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
  aksClusterUser: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = { name: acrName }
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: kvName }
resource aks 'Microsoft.ContainerService/managedClusters@2024-05-01' existing = { name: aksName }

resource kubeletAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, 'kubelet', roles.acrPull)
  scope: acr
  properties: {
    principalId: kubeletObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
  }
}

resource deployerAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, deployerObjectId, roles.acrPush)
  scope: acr
  properties: {
    principalId: deployerObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPush)
  }
}

resource workloadKv 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, 'workload', roles.kvSecretsUser)
  scope: kv
  properties: {
    principalId: workloadPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.kvSecretsUser)
  }
}

resource deployerKv 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, deployerObjectId, roles.kvAdmin)
  scope: kv
  properties: {
    principalId: deployerObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.kvAdmin)
  }
}

resource deployerAksAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, deployerObjectId, roles.aksRbacClusterAdmin)
  scope: aks
  properties: {
    principalId: deployerObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.aksRbacClusterAdmin)
  }
}

resource deployerAksUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, deployerObjectId, roles.aksClusterUser)
  scope: aks
  properties: {
    principalId: deployerObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.aksClusterUser)
  }
}
