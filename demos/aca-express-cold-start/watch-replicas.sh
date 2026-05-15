#!/usr/bin/env bash
# watch-replicas.sh — Live replica count for an ACA Express app
#
# Usage:
#   ./watch-replicas.sh <app-name> <resource-group>
#
# Or set env vars:
#   CONTAINER_APP_NAME=myapp AZURE_RESOURCE_GROUP=myrg ./watch-replicas.sh
#
# Polls az containerapp replica list every 3 seconds and prints a line
# whenever the count changes. Run this in a side terminal while using
# the cold-start dashboard to see the replica count drop to zero and
# then climb back up on each cold start.

set -euo pipefail

APP_NAME="${1:-${CONTAINER_APP_NAME:-}}"
RG="${2:-${AZURE_RESOURCE_GROUP:-}}"

if [[ -z "$APP_NAME" || -z "$RG" ]]; then
  echo "Usage: $0 <app-name> <resource-group>" >&2
  echo "       or set CONTAINER_APP_NAME and AZURE_RESOURCE_GROUP env vars" >&2
  exit 1
fi

echo "Watching replicas for '$APP_NAME' in '$RG' (Ctrl+C to stop)…"
echo "Tip: ACA Express scales to zero automatically when idle."
echo ""

prev_count=""
while true; do
  count=$(az containerapp replica list \
    --name "$APP_NAME" \
    --resource-group "$RG" \
    --query "length(@)" \
    --output tsv 2>/dev/null) || count="?"

  ts=$(date +%H:%M:%S)

  if [[ "$count" != "$prev_count" ]]; then
    if [[ "$count" == "0" ]]; then
      icon="🔵"
      msg="Scaled to zero — next request will cold-start"
    elif [[ "$count" == "1" ]]; then
      icon="🟢"
      msg="1 replica running"
    elif [[ "$count" == "?" ]]; then
      icon="❓"
      msg="Unable to query (check az login)"
    else
      icon="🟢"
      msg="$count replicas running"
    fi
    echo "$ts  $icon  $count replica(s) — $msg"
    prev_count="$count"
  fi

  sleep 3
done
