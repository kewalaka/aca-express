# ACA Express / Sandbox Demos

Runnable demos for **Azure Container Apps Express** and **ACA Sandboxes**.

## Demos

| Demo | Description |
|------|-------------|
| [`demos/aca-express-cold-start`](demos/aca-express-cold-start/) | Browser dashboard that measures real-world cold-start latency for ACA Express instances |
| [`demos/aca-sandboxes`](demos/aca-sandboxes/) | End-to-end CLI demo showing suspend/resume, snapshotting, rollback, and egress control |

## GitHub Actions

| Workflow | Trigger |
|----------|---------|
| [`aca-express-cold-start-publish`](.github/workflows/aca-express-cold-start-publish.yml) | Push to `main` touching `demos/aca-express-cold-start/**` — builds and pushes the container image to GHCR |
