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

---

## Background

### Azure Container Apps Express

[Azure Container Apps Express](https://learn.microsoft.com/en-us/azure/container-apps/express-faq) is an environment tier in **Public Preview** that removes infrastructure decisions from deployment. There is no environment to provision, no networking to configure, no scaling rules to write — you bring a container image and Express handles everything else.

Key characteristics:

- **Instant provisioning** — apps running in seconds, not minutes
- **Sub-second cold starts** — fast enough for interactive UIs and on-demand agent endpoints
- **Scale to and from zero** — automatic, no configuration required
- **Per-second billing** — pay only for what you use, same as the ACA consumption plan
- **Production-ready defaults** — ingress, secrets, environment variables, and observability built in

Express is designed for two audiences: developers who want to ship fast (SaaS apps, APIs, web dashboards, prototypes) and agent-first systems that deploy endpoints on demand (MCP servers, tool-use endpoints, workflow APIs).

> **Preview regions:** East Asia and West Central US. More regions coming.

Express is [built on ACA Sandboxes](https://learn.microsoft.com/en-us/azure/container-apps/express-faq#what-is-the-relationship-between-express-and-azure-container-apps-sandboxes) internally — the platform layer that provides fast startup from prewarmed pools.

📖 [Announcing ACA Express (blog)](https://techcommunity.microsoft.com/blog/appsonazureblog/introducing-azure-container-apps-express/4519150) · [Express FAQ](https://learn.microsoft.com/en-us/azure/container-apps/express-faq)

---

### Azure Container Apps Sandboxes

[ACA Sandboxes](https://github.com/microsoft/azure-container-apps/blob/main/docs/early/sandboxes-overview.md) (**Early Access**) provide fast, secure, isolated compute environments with built-in suspend and resume capabilities. They are a first-class resource type (`Microsoft.App/SandboxGroups`) in Container Apps, alongside apps, jobs, and dynamic sessions.

Where [Dynamic Sessions](https://learn.microsoft.com/en-us/azure/container-apps/sessions) provide a managed execution experience that abstracts away infrastructure, Sandboxes give you direct, programmable control over isolated compute environments — including state snapshots, persistent storage, and networking policies.

| | Dynamic Sessions | ACA Sandboxes |
|---|---|---|
| Lifecycle control | Managed by session pool | You manage: create, suspend, resume, delete |
| State across tasks | ✗ ephemeral | ✅ suspend/resume |
| Snapshots | ✗ | ✅ named, restorable |
| Persistent storage | ✗ | ✅ Azure Blob + Data Disk volumes |
| Egress policies | Basic isolation | ✅ Allow/deny/transform/rewrite |
| Credential injection | ✗ | ✅ Via Transform rules |

> **Early Access:** Resources created during Early Access may not be compatible with future Public Preview releases. Requires `Container Apps SandboxGroup Data Owner` role.

📖 [Sandboxes overview](https://github.com/microsoft/azure-container-apps/blob/main/docs/early/sandboxes-overview.md) · [Dynamic Sessions docs](https://learn.microsoft.com/en-us/azure/container-apps/sessions)
