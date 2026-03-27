#!/usr/bin/env bash
set -euo pipefail

# Triage Agent: analyze bug report, locate root cause, generate fix plan

REPO="${REPO:-.}"
BUG_REPORT="${BUG_REPORT:-}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== [triage] Starting bug triage for request: $REQUEST_ID ===" >&2

TRIAGE_OUTPUT=$(cd "$REPO" && echo "Analyze the following bug report:

$BUG_REPORT

Search the codebase to locate the root cause, classify severity, and produce a fix plan.
Output ONLY a valid JSON object matching the format specified in your instructions. No markdown wrapping." \
| claude -p \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/triage.md")" \
  2>/dev/null) || TRIAGE_OUTPUT="{\"error\": \"triage agent failed\", \"request_id\": \"$REQUEST_ID\", \"fix_plan\": \"Investigate and fix: $BUG_REPORT\"}"

echo "$TRIAGE_OUTPUT"

echo "=== [triage] Bug triage complete ===" >&2
