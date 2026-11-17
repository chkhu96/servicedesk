#!/usr/bin/env bash
# Run on JUMPBOX. Self-signed cert -> Key Vault (data plane, over private endpoint).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
KV=$(jq -r .keyVaultName.value outputs.json)

echo "DNS check (expect 10.10.4.x):"; getent hosts "$KV.vault.azure.net"
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -subj "/CN=$APP_HOST" -addext "subjectAltName=DNS:$APP_HOST" \
  -keyout /tmp/tls.key -out /tmp/tls.crt
cat /tmp/tls.key /tmp/tls.crt > /tmp/servicedesk-tls.pem

az keyvault certificate import --vault-name "$KV" -n servicedesk-tls -f /tmp/servicedesk-tls.pem \
  --policy '{"secretProperties":{"contentType":"application/x-pem-file"}}' -o none
sudo cp /tmp/tls.crt /usr/local/share/ca-certificates/servicedesk.crt && sudo update-ca-certificates >/dev/null
rm -f /tmp/tls.key /tmp/servicedesk-tls.pem
echo "Cert imported and trusted on jumpbox."
