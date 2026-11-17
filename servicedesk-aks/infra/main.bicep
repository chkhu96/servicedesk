// Ticketing Lite - private AKS learning lab (resource-group scope)
targetScope = 'resourceGroup'

@description('Short prefix for resource names (3-8 lowercase chars)')
@minLength(3)
@maxLength(8)
param prefix string = 'sdlab'

param location string = resourceGroup().location

@description('Object ID of the user deploying the lab (az ad signed-in-user show --query id -o tsv)')
param deployerObjectId string

@description('UPN of the deployer, used as SQL Entra admin login name')
param deployerUpn string

@description('SSH public key for the jumpbox')
param jumpboxSshPublicKey string

@secure()
@description('SQL admin password used by the app connection string (phase 1, before passwordless)')
param sqlAdminPassword string

param sqlAdminLogin string = 'sdadmin'
param kubernetesVersion string = ''
param appNamespace string = 'servicedesk'
param appServiceAccount string = 'servicedesk-sa'

var suffix = uniqueString(resourceGroup().id)
var names = {
  vnet: '${prefix}-vnet'
  aks: '${prefix}-aks'
  acr: toLower('${prefix}acr${suffix}')
  kv: take('${prefix}-kv-${suffix}', 24)
  sql: '${prefix}-sql-${suffix}'
  law: '${prefix}-law'
}

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: names.vnet
    prefix: prefix
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    name: names.law
  }
}

module dns 'modules/privatedns.bicep' = {
  name: 'privatedns'
  params: {
    vnetId: network.outputs.vnetId
  }
}

module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    name: names.acr
    peSubnetId: network.outputs.peSubnetId
    dnsZoneId: dns.outputs.acrZoneId
  }
}

module sql 'modules/sql.bicep' = {
  name: 'sql'
  params: {
    location: location
    name: names.sql
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
    entraAdminObjectId: deployerObjectId
    entraAdminLogin: deployerUpn
    peSubnetId: network.outputs.peSubnetId
    dnsZoneId: dns.outputs.sqlZoneId
  }
}

module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    location: location
    prefix: prefix
    vnetName: names.vnet
  }
  dependsOn: [ network ]
}

module aks 'modules/aks.bicep' = {
  name: 'aks'
  params: {
    location: location
    name: names.aks
    kubernetesVersion: kubernetesVersion
    aksSubnetId: network.outputs.aksSubnetId
    controlPlaneIdentityId: identity.outputs.controlPlaneIdentityId
    lawId: monitoring.outputs.lawId
  }
  dependsOn: [ identity ] // Network Contributor must exist before cluster creation
}

module kv 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    name: names.kv
    peSubnetId: network.outputs.peSubnetId
    dnsZoneId: dns.outputs.kvZoneId
    sqlConnectionString: 'Driver={ODBC Driver 18 for SQL Server};Server=tcp:${sql.outputs.fqdn},1433;Database=${sql.outputs.dbName};Uid=${sqlAdminLogin};Pwd=${sqlAdminPassword};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;'
  }
}

module workload 'modules/workload-identity.bicep' = {
  name: 'workload-identity'
  params: {
    location: location
    prefix: prefix
    oidcIssuerUrl: aks.outputs.oidcIssuerUrl
    namespace: appNamespace
    serviceAccount: appServiceAccount
  }
}

module rbac 'modules/rbac.bicep' = {
  name: 'rbac'
  params: {
    acrName: names.acr
    kvName: names.kv
    aksName: names.aks
    kubeletObjectId: aks.outputs.kubeletObjectId
    workloadPrincipalId: workload.outputs.principalId
    deployerObjectId: deployerObjectId
  }
  dependsOn: [ acr, kv ]
}

module jumpbox 'modules/jumpbox.bicep' = {
  name: 'jumpbox'
  params: {
    location: location
    prefix: prefix
    jumpboxSubnetId: network.outputs.jumpboxSubnetId
    bastionSubnetId: network.outputs.bastionSubnetId
    sshPublicKey: jumpboxSshPublicKey
  }
}

output aksName string = names.aks
output acrName string = names.acr
output acrLoginServer string = acr.outputs.loginServer
output keyVaultName string = names.kv
output sqlServerFqdn string = sql.outputs.fqdn
output workloadClientId string = workload.outputs.clientId
output tenantId string = tenant().tenantId
output bastionName string = jumpbox.outputs.bastionName
output jumpboxVmId string = jumpbox.outputs.vmId
output appDnsZone string = dns.outputs.appZoneName
