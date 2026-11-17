using 'main.bicep'

param prefix = 'sdlab'
param deployerObjectId = readEnvironmentVariable('DEPLOYER_OBJECT_ID')
param deployerUpn = readEnvironmentVariable('DEPLOYER_UPN')
param jumpboxSshPublicKey = readEnvironmentVariable('JUMPBOX_SSH_PUBKEY')
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')
