#!/usr/bin/env bash
# Run on JUMPBOX.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
ENV="${1:-dev}"

az aks get-credentials -g "$RG" -n "$(jq -r .aksName.value outputs.json)" --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
kubectl get gatewayclass

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# NOTE: no --wait. Post-install migration hook must run before APIs pass /readyz.
helm upgrade --install servicedesk charts/servicedesk -n "$NAMESPACE" \
  -f charts/servicedesk/values-$ENV.yaml \
  --set image.registry="$(jq -r .acrLoginServer.value outputs.json)" \
  --set image.tag="$TAG" \
  --set azure.tenantId="$(jq -r .tenantId.value outputs.json)" \
  --set azure.workloadClientId="$(jq -r .workloadClientId.value outputs.json)" \
  --set azure.keyVaultName="$(jq -r .keyVaultName.value outputs.json)" \
  --set gateway.hostname="$APP_HOST" \
  --timeout 10m

kubectl get pods,gateway,httproute -n "$NAMESPACE"
