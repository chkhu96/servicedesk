#!/usr/bin/env bash
# Run on JUMPBOX. Points servicedesk.lab.internal at the Gateway's internal LB IP.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

echo "Waiting for gateway address..."
for i in $(seq 1 30); do
  IP=$(kubectl get gateway servicedesk-gw -n "$NAMESPACE" -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
  [ -n "$IP" ] && break; sleep 10
done
[ -z "$IP" ] && { echo "No gateway IP yet: kubectl describe gateway servicedesk-gw -n $NAMESPACE"; exit 1; }
case "$IP" in 10.10.*) echo "Internal IP: $IP";; *) echo "WARNING: $IP is not private - internal LB annotation not applied"; exit 1;; esac

ZONE=lab.internal; REC=${APP_HOST%.$ZONE}
az network private-dns record-set a delete -g "$RG" -z "$ZONE" -n "$REC" --yes 2>/dev/null || true
az network private-dns record-set a add-record -g "$RG" -z "$ZONE" -n "$REC" -a "$IP" -o none

sleep 5
curl -s "https://$APP_HOST/api/reports/summary" | jq .
