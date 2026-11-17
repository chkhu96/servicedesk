#!/usr/bin/env bash
# Run on JUMPBOX. ACR has public access disabled, so build locally and push over the private endpoint.
# (az acr build / ACR Tasks cannot reach a network-restricted registry without a dedicated agent pool.)
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
ACR=$(jq -r .acrName.value outputs.json)
LOGIN=$(jq -r .acrLoginServer.value outputs.json)

echo "DNS check (expect 10.10.4.x):"; getent hosts "$LOGIN"
az acr login -n "$ACR"

for app in ticket_api report_api worker; do
  img=${app//_/-}
  docker build -t "$LOGIN/$img:$TAG" --build-arg APP=$app services/python
  docker push "$LOGIN/$img:$TAG"
done
docker build -t "$LOGIN/web:$TAG" services/web
docker push "$LOGIN/web:$TAG"

az acr repository list -n "$ACR" -o table
