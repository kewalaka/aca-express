# ACA Express Cold-Start Dashboard Demo

A minimal demo that measures **real-world cold-start latency** for Azure Container Apps Express instances.

## What this demo shows

Azure Container Apps (ACA) Express can scale to zero when idle. The first request after scale-to-zero incurs a "cold start" — the time for ACA to spin up a new container instance. This demo lets you:

- Trigger a cold start and see the full round-trip time in real time
- Break down **client round-trip** vs **server boot time** vs **ACA routing overhead**
- Compare cold vs warm responses side-by-side
- Keep a history of the last 5 requests

---

## Files

| File | Purpose |
|------|---------|
| `server.js` | Minimal Node.js HTTP server (zero npm deps) |
| `Dockerfile` | Container image definition |
| `index.html` | Self-contained browser dashboard |

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
