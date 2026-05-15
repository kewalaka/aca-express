# ACA Sandboxes Demo — "The Agent That Never Forgets"

> **Early Access.** Requires `aca` CLI and a subscription with ACA Sandboxes enabled.

## The pitch (30 seconds)

AI agents using dynamic sessions restart from scratch every task — reinstall packages, re-clone repos, re-warm models.
With ACA Sandboxes the agent's workspace **persists**: suspend between tasks (zero cost), resume sub-second, rollback from any checkpoint.

```
Dynamic sessions                    ACA Sandboxes
─────────────────────────────────   ──────────────────────────────────
Every task: cold start (30-90s)  →  Start warm from snapshot (<1s)
Session evicted → all work lost  →  Suspend/resume, full state intact
Agent breaks something → restart →  Restore from named checkpoint
API keys in agent code / env     →  Platform injects credentials
```

---

## Setup

### 1 — Install the `aca` CLI

```bash
curl -fsSL https://raw.githubusercontent.com/microsoft/azure-container-apps/main/docs/early/aca-cli/install.sh | sh
```

### 2 — Log in and configure

```bash
az login

# Create a resource group (skip if you have one)
az group create --name aca-sandbox-demo-rg --location eastus2

# Create a sandbox group
aca sandboxgroup create --name aca-sandbox-demo --location eastus2 --set-config

# Grant yourself data-plane access
aca sandboxgroup role create \
  --role "Container Apps SandboxGroup Data Owner" \
  --principal-id $(az ad signed-in-user show --query id -o tsv)

# Verify
aca doctor
```

### 3 — (Optional) Store the OpenAI key in the sandbox group's secrets store

This is what enables credential injection in Act 4. The sandbox code never sees the raw key.

```bash
aca sandboxgroup secret upsert \
  --name openai-api-key \
  --values openai-api-key=sk-YOUR-KEY-HERE
```

---

## Running the demo

```bash
chmod +x demo.sh

# Guided mode — pauses between acts (live demo)
./demo.sh

# Auto mode — no pauses (screencast / CI)
./demo.sh --auto

# Clean up everything afterwards
./demo.sh --cleanup
```

---

## What each act shows

### Act 1 — 📦 Setup Once, Reuse Forever

Creates a sandbox, installs `pandas / numpy / scikit-learn / matplotlib`, then takes a **snapshot called `demo-warm-baseline`**.

Every future agent starts from that snapshot — no reinstall, no cold start.

```bash
# Start warm, not from scratch
aca sandbox create --snapshot demo-warm-baseline
```

**Why this beats dynamic sessions:** dynamic session pools do support custom container images, but you can't snapshot a *running* session mid-task. With sandboxes, any state — installed packages *and* half-finished work — can be captured and reused.

---

### Act 2 — ⚡ Suspend/Resume

Trains a scikit-learn model, writes state to `/workspace/model_state.json`, then **suspends** the sandbox (releasing all compute, zero cost).

On resume, the model coefficients are verified to be exactly as left. The agent "wakes up" rather than starting over.

**Suspend modes:**

| Mode | What's preserved | Resume latency |
|---|---|---|
| `Memory` (default) | RAM + disk | **Sub-second** |
| `Disk` | Disk only | Cold start |

**Why this beats dynamic sessions:** sessions have a cooldown period; after that the pool recycles the slot and everything is gone. There is no persist-across-idle capability.

---

### Act 3 — 🔄 Checkpoint & Rollback

Takes a **snapshot `demo-work-checkpoint`** at a known-good point, then simulates a destructive agent action (`rm -rf /workspace`).

Recovery: `aca sandbox create --snapshot demo-work-checkpoint` — the workspace is restored in seconds, model intact.

**Why this beats dynamic sessions:** dynamic sessions have no snapshot mechanism. The only recovery option is to re-run everything.

---

### Act 4 — 🔐 Egress Guard

Applies [`egress-policy.yaml`](egress-policy.yaml) to the sandbox:

- **Default: Deny** — nothing goes out unless explicitly allowed
- **Allowed:** PyPI, GitHub (legitimate agent needs)
- **Transform rule:** calls to `api.openai.com` get an `Authorization: Bearer …` header injected from the sandbox group's secrets store

The agent code calls OpenAI *without an API key in code or environment*. The platform attaches it invisibly.

An exfiltration attempt to `pastebin.com` is blocked and logged in egress decisions.

**Why this beats dynamic sessions:** dynamic sessions offer basic sandboxing (isolated VMs), but there are no programmable egress rules and no credential injection.

---

## Key differentiators summary

| Capability | Dynamic Sessions | ACA Sandboxes |
|---|---|---|
| State across tasks | ✗ ephemeral | ✅ suspend/resume |
| Snapshots | ✗ | ✅ named, restorable |
| Persistent storage | ✗ | ✅ volumes (Blob, DataDisk) |
| Egress rules | ✗ basic isolation | ✅ allow/deny/transform/rewrite |
| Credential injection | ✗ | ✅ via Transform rules |
| Custom disk images | ✅ custom container | ✅ OCI → disk image |
| Developer control | Pool manages lifecycle | ✅ you control lifecycle |
| Scale to zero | ✅ | ✅ |

---

## Files

| File | Purpose |
|---|---|
| `demo.sh` | Runnable end-to-end demo script |
| `sandbox.yaml` | Declarative sandbox spec (resources, lifecycle, egress) |
| `egress-policy.yaml` | Egress policy: deny-by-default + OpenAI key injection |
