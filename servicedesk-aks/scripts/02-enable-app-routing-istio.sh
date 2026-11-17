#!/usr/bin/env bash
# Run from LAPTOP. Enables managed Gateway API CRDs + app routing Istio implementation.
# Done via CLI (control-plane op, works on private clusters) because the Bicep schema for
# this feature may lag. Verify flags with: az aks update --help | grep -i -E "gateway|istio"
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
AKS=$(jq -r .aksName.value outputs.json)

az aks update -g "$RG" -n "$AKS" --enable-gateway-api --enable-app-routing-istio

echo "Check (from jumpbox later): kubectl get gatewayclass  -> expect 'approuting-istio'"
