#!/usr/bin/env bash
# Run from your LAPTOP (or Cloud Shell). Creates everything in IaC.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

az group create -n "$RG" -l "$LOCATION" -o none

export DEPLOYER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
export DEPLOYER_UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv)
[ -f ~/.ssh/sdlab_jumpbox ] || ssh-keygen -t rsa -b 4096 -f ~/.ssh/sdlab_jumpbox -N "" -C sdlab
export JUMPBOX_SSH_PUBKEY=$(cat ~/.ssh/sdlab_jumpbox.pub)
export SQL_ADMIN_PASSWORD="${SQL_ADMIN_PASSWORD:-$(openssl rand -base64 24 | tr -d '/+=' )Aa1!}"

az deployment group create -g "$RG" -n servicedesk-lab \
  -f infra/main.bicep -p infra/main.bicepparam -o none

az deployment group show -g "$RG" -n servicedesk-lab --query properties.outputs -o json > outputs.json
echo "Deployment complete. Outputs saved to outputs.json"
jq -r 'to_entries[] | "\(.key) = \(.value.value)"' outputs.json
