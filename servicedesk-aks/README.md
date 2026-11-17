# Ticketing Lite on private AKS (learning lab)

Mini IT service desk app on a private AKS cluster. Infrastructure is defined in Bicep and the app is deployed with Helm.

| Layer | What |
|---|---|
| IaC (`infra/`) | VNet, NAT GW, Bastion + jumpbox, private AKS (Azure RBAC, workload identity, Key Vault CSI, Container Insights), ACR Premium, Key Vault, Azure SQL serverless, private endpoints + private DNS zones, identities + RBAC |
| Ingress | Gateway API, GatewayClass `approuting-istio` (AKS app routing add-on), **internal** LB, TLS from Key Vault |
| App (`services/`) | `web` (nginx static UI), `ticket-api`, `report-api` (FastAPI), `worker` (migration Job + SLA CronJob) |
| Helm (`charts/servicedesk`) | Deployments, Services, HPA, PDB, SA, SecretProviderClass, Gateway, HTTPRoute, hook Job, CronJob |

```
Laptop --(az network bastion ssh)--> Bastion --> Jumpbox (10.10.5.0/28)
Jumpbox --https://servicedesk.lab.internal--> Gateway internal LB (snet-aks)
   /             -> web
   /api/tickets  -> ticket-api --\
   /api/reports  -> report-api ----> SQL PE (10.10.4.x)   [privatelink.database.windows.net]
   pods  --CSI + workload identity--> Key Vault PE         [privatelink.vaultcore.azure.net]
   nodes --pull--> ACR PE                                  [privatelink.azurecr.io]
API server: private, zone privatelink.<region>.azmk8s.io (AKS-managed)
```

## Prerequisites (laptop)
- Azure CLI (recent version), `jq`, `openssl`, `ssh`
- `az extension add -n bastion` (for `az network bastion ssh/tunnel`, which needs a Windows or Linux shell; WSL works)
- **Owner** on the subscription or resource group (the templates create role assignments)
- Region with quota for about 6 vCPU of Dsv5 + 2 vCPU of B-series
- Register providers if you haven't already: `Microsoft.ContainerService`, `Microsoft.ContainerRegistry`, `Microsoft.KeyVault`, `Microsoft.Sql`, `Microsoft.Network`, `Microsoft.OperationalInsights`

## Deploy

| # | Where | Command | Expected |
|---|---|---|---|
| 0 | Laptop | Edit `scripts/env.sh` (RG, region) then `az login` | |
| 1 | Laptop | `./scripts/01-deploy-infra.sh` | About 15–25 min. Creates `outputs.json` |
| 2 | Laptop | `./scripts/02-enable-app-routing-istio.sh` | Gateway API + app routing Istio enabled |
| 3 | Laptop | `./scripts/03-copy-to-jumpbox.sh` | Repo copied to `~/servicedesk`. Prints the SSH command |
| 4 | Jumpbox | `cat /var/log/jumpbox-ready` (cloud-init finished), then `az login --use-device-code`, then **log out and back in** (docker group) | |
| 5 | Jumpbox | `cd ~/servicedesk && ./scripts/04-build-push.sh` | 4 images in ACR |
| 6 | Jumpbox | `./scripts/05-tls-cert.sh` | Cert `servicedesk-tls` in Key Vault |
| 7 | Jumpbox | `./scripts/06-helm-install.sh dev` | Pods start. APIs become Ready after `db-migrate` completes |
| 8 | Jumpbox | `./scripts/07-dns-record.sh` | A record created. `curl` returns a JSON summary |

Open the UI with a Windows jumpbox/browser, or from the Linux jumpbox:
`curl https://servicedesk.lab.internal/api/tickets | jq`

## Validation checklist
- From your laptop, `kubectl get nodes` **fails**. From the jumpbox it works (private API server).
- `nslookup <acr>.azurecr.io`, `<kv>.vault.azure.net` and `<sql>.database.windows.net` from the jumpbox return `10.10.4.x`.
- `kubectl get gateway -n servicedesk` returns an address in `10.10.x.x`, not a public IP.
- `kubectl get secret servicedesk-tls -n servicedesk` exists (CSI sync).
- `kubectl logs job/...` from the `sla-checker` CronJob shows `newly breached: N`.

## Day-2 exercises
1. **Helm upgrade/rollback:** change `index.html`, build tag `1.0.1`, set `TAG=1.0.1` and re-run step 7. Then run `helm rollback servicedesk 1 -n servicedesk`.
2. **Secret rotation:** change the `sla-config` secret in Key Vault. CSI polls every 2 minutes, and the next CronJob run uses the new SLA hours.
3. **Weighted routing:** deploy `report-api` v2 (second release, or add a v2 Deployment/Service) and give the `/api/reports` rule two `backendRefs` with `weight: 90` / `weight: 10`.
4. **HPA:** `values-prod.yaml`, then load-test with `hey`/`ab` from the jumpbox and watch `kubectl get hpa -w`.
5. **Passwordless SQL:** create a contained user for the workload identity (`CREATE USER [sdlab-servicedesk-id] FROM EXTERNAL PROVIDER`), switch the connection string to `Authentication=ActiveDirectoryMsi;UID=<clientId>`, and enable Entra-only auth.
6. **Hub-spoke:** move private DNS zones + Bastion to a hub VNet and peer.

## Known gotchas
- **ACR Tasks** (`az acr build`) cannot reach a registry that has public access disabled. Build on the jumpbox.
- **No `--wait` on helm:** the migration runs as a post-install hook, and API readiness depends on the schema.
- **Internal Gateway:** this relies on `spec.infrastructure.annotations` being passed through to the LB Service. If step 8 reports a public IP, check the app routing Gateway API docs for the supported customisation (ConfigMap / annotation allow-list).
- **App routing Istio vs Istio add-on:** you can't enable both on the same cluster. Switching to the full mesh means disabling app routing Istio first, and changing `gateway.className` to `istio`.
- **Key Vault soft delete:** after `destroy`, purge the vault before redeploying with the same name.
- The Bicep API versions and the `az aks update` flags were written without a live deployment. Run `az bicep build -f infra/main.bicep` and `az deployment group what-if` first.

## Cost control
`./scripts/99-cost-control.sh stop|start|destroy`. When AKS and the jumpbox are stopped, the main fixed costs are Bastion Standard, ACR Premium, the NAT gateway and IPs. SQL serverless auto-pauses after 60 minutes.
