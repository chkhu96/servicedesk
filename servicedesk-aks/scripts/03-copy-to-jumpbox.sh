#!/usr/bin/env bash
# Run from LAPTOP. Copies this repo to the jumpbox via a Bastion tunnel, then opens SSH.
# Alternative: push the repo to GitHub/Azure Repos and 'git clone' on the jumpbox.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
BASTION=$(jq -r .bastionName.value outputs.json)
VMID=$(jq -r .jumpboxVmId.value outputs.json)

az network bastion tunnel -g "$RG" -n "$BASTION" --target-resource-id "$VMID" \
  --resource-port 22 --port 2222 &
TUNNEL=$!
sleep 8
tar czf /tmp/servicedesk.tgz --exclude=.git .
scp -P 2222 -i ~/.ssh/sdlab_jumpbox -o StrictHostKeyChecking=no /tmp/servicedesk.tgz azureuser@127.0.0.1:~
ssh -p 2222 -i ~/.ssh/sdlab_jumpbox azureuser@127.0.0.1 'mkdir -p servicedesk && tar xzf servicedesk.tgz -C servicedesk'
kill $TUNNEL
echo "Copied. Connect with:"
echo "az network bastion ssh -g $RG -n $BASTION --target-resource-id $VMID --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/sdlab_jumpbox"
