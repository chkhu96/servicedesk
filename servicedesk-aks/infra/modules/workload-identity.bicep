param location string
param prefix string
param oidcIssuerUrl string
param namespace string
param serviceAccount string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-servicedesk-id'
  location: location
}

resource fic 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: uami
  name: 'aks-${namespace}-${serviceAccount}'
  properties: {
    issuer: oidcIssuerUrl
    subject: 'system:serviceaccount:${namespace}:${serviceAccount}'
    audiences: [ 'api://AzureADTokenExchange' ]
  }
}

output clientId string = uami.properties.clientId
output principalId string = uami.properties.principalId
