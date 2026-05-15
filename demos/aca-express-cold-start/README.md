# ACA Express Cold-Start Dashboard Demo

A minimal demo that measures **real-world cold-start latency** for Azure Container Apps Express instances.

---

## About ACA Express

[Azure Container Apps Express](https://learn.microsoft.com/en-us/azure/container-apps/express-faq) is an environment tier in **Public Preview** that removes infrastructure decisions. There is no environment to provision, no networking to configure, no scaling rules to write — you bring a container image and Express handles everything else.

| Characteristic | Detail |
|---|---|
| **Provisioning** | Apps running in seconds, not minutes |
| **Cold starts** | Sub-second scale-from-zero startup |
| **Scaling** | Automatic scale-to-zero, up to 2 replicas during preview |
| **Billing** | Per-second vCPU + memory, same as ACA consumption plan (free grant applies) |
| **Preview regions** | East Asia · West Central US |
| **Not yet in preview** | VNet integration, custom domains, managed identity, autoscaling, GPU |

Express is [built on ACA Sandboxes](https://learn.microsoft.com/en-us/azure/container-apps/express-faq#what-is-the-relationship-between-express-and-azure-container-apps-sandboxes) internally — the platform layer that provides fast startup from prewarmed pools.

📖 [Express FAQ](https://learn.microsoft.com/en-us/azure/container-apps/express-faq) · [Announcing ACA Express (blog)](https://techcommunity.microsoft.com/blog/appsonazureblog/introducing-azure-container-apps-express/4519150)

---

## What this demo shows

Azure Container Apps Express scales to zero automatically when idle. The first request after scale-to-zero is a cold start — the time for ACA to spin up a new container instance. This demo lets you:

- **Trigger Cold Start** — measure the full round-trip time in real time
- **Reset for Cold Start** — send a shutdown signal to the live container, poll until it goes offline, then you're set up for a genuine cold start on the next trigger
- **Breakdown** — client round-trip vs server boot time (`bootMs`)
- **History** — last 5 requests with cold/warm classification

### Watching replicas from the CLI

Run `watch-replicas.sh` in a side terminal for live replica count telemetry:

```bash
chmod +x watch-replicas.sh
./watch-replicas.sh <app-name> <resource-group>
```

You'll see `🔵 Scaled to zero` after a Reset, then `🟢 1 replica running` after the next cold start.

---

## Files

| File | Purpose |
|------|---------|
| `server.js` | Minimal Node.js HTTP server (zero npm deps) — exposes `GET /` and `POST /exit` |
| `Dockerfile` | Container image definition |
| `index.html` | Self-contained browser dashboard |
| `watch-replicas.sh` | CLI replica-count poller (requires `az` CLI) |

---

## Deploy to ACA Express

### 1. Build and push the container image

```bash
az acr login --name acrsharedacr1devauea

docker build -t acrsharedacr1devauea.azurecr.io/aca-express-demo:latest .
docker push acrsharedacr1devauea.azurecr.io/aca-express-demo:latest
```

### 2. Create the Container Apps environment (Express)

```bash
RESOURCE_GROUP="rg-aca-demo"
LOCATION="australiaeast"
ENVIRONMENT="aca-express-env"
APP_NAME="cold-start-demo"

az group create --name $RESOURCE_GROUP --location $LOCATION

az containerapp env create \
  --name $ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

### 3. Deploy the container app

```bash
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT \
  --image acrsharedacr1devauea.azurecr.io/aca-express-demo:latest \
  --registry-server acrsharedacr1devauea.azurecr.io \
  --target-port 8080 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 1 \
  --cpu 0.25 --memory 0.5Gi
```

Setting `--min-replicas 0` enables scale-to-zero (required for cold starts).

### 4. Get the app URL

```bash
az containerapp show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn \
  --output tsv
```

---

## Using the Dashboard

1. Open `index.html` directly in your browser (no server needed — it's a single self-contained file).
2. Paste your ACA Express URL into the input field (e.g. `https://cold-start-demo.region.azurecontainerapps.io`).
3. Click **🚀 Trigger Cold Start**.
4. Watch the live millisecond timer count up as the request travels to ACA.
5. When the response arrives, the timer freezes and the breakdown appears:
   - **Client Round-Trip** — total time measured in the browser
   - **Server Boot (bootMs)** — time from process start to response, as reported by the server
   - **ACA Routing Est.** — `round-trip − bootMs`, an estimate of network + ACA overhead
6. Click **🔥 Fire Again (Warm)** to send a second request to the already-warm instance and compare.

---

## Triggering a cold start

The container must be scaled to zero before clicking **Trigger Cold Start**. You can force this two ways:

### Option A — Wait for idle scale-down (automatic)

ACA Express scales to zero after a period of inactivity (typically a few minutes). Simply wait, then fire the request.

### Option B — Force a restart via CLI

```bash
# Deactivate the current revision (scales to zero immediately)
az containerapp revision deactivate \
  --revision $(az containerapp revision list \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" -o tsv) \
  --resource-group $RESOURCE_GROUP

# Re-activate it so it can respond to the next request
az containerapp revision activate \
  --revision $(az containerapp revision list \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" -o tsv) \
  --resource-group $RESOURCE_GROUP
```

Or simply deploy a new revision to force a fresh cold start:

```bash
az containerapp update \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --image acrsharedacr1devauea.azurecr.io/aca-express-demo:latest
```

---

## Server API

`GET /` returns:

```json
{
  "appName":      "cold-start-demo",
  "revision":     "cold-start-demo--abc123",
  "region":       "australiaeast",
  "hostname":     "cold-start-demo--abc123-xyz",
  "bootMs":       42,
  "requestCount": 1,
  "uptimeMs":     1234
}
```

All responses include `Access-Control-Allow-Origin: *` so the browser dashboard can call any ACA Express endpoint without a proxy.
