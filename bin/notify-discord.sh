#!/usr/bin/env bash
set -euo pipefail

# Send status notification to Discord via OpenClaw gateway API

OPENCLAW_URL="${OPENCLAW_URL:-http://100.101.193.115:18789}"
MESSAGE="${1:-Pipeline update}"

curl -sf -X POST "${OPENCLAW_URL}/api/message" \
  -H "Content-Type: application/json" \
  ${OPENCLAW_TOKEN:+-H "Authorization: Bearer $OPENCLAW_TOKEN"} \
  -d "{\"message\": $(echo "$MESSAGE" | jq -Rs .)}" \
  2>/dev/null || echo "Discord notification failed (gateway may be offline)" >&2
