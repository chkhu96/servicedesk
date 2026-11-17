#!/usr/bin/env bash
# Run from LAPTOP. stop | start | destroy
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
AKS=$(jq -r .aksName.value outputs.json)
case "${1:-}" in
  stop)    az aks stop -g "$RG" -n "$AKS"; az vm deallocate -g "$RG" -n "$PREFIX-jumpbox" ;;
  start)   az aks start -g "$RG" -n "$AKS"; az vm start -g "$RG" -n "$PREFIX-jumpbox" ;;
  destroy) az group delete -n "$RG" --yes --no-wait
           echo "Key Vault is soft-deleted (7 days). Purge if redeploying: az keyvault purge -n $(jq -r .keyVaultName.value outputs.json)" ;;
  *) echo "usage: $0 stop|start|destroy" ;;
esac
