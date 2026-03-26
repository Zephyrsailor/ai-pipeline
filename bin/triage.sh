#!/usr/bin/env bash
set -euo pipefail

# Triage Agent: analyze bug report, locate root cause, generate fix plan

REPO="${REPO:-.}"
BUG_REPORT="${BUG_REPORT:-}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== [triage] Starting bug triage for request: $REQUEST_ID ===" >&2

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/triage.md")" \
  --prompt "Analyze the following bug report for the repo at $REPO:

$BUG_REPORT

Search the codebase to locate the root cause, classify severity, and produce a fix plan.
Output ONLY a valid JSON object matching the format specified in your instructions. No markdown wrapping." \
  --cwd "$REPO" \
  --output-format json \
  --max-turns 5 \
  2>/dev/null || echo "{\"error\": \"triage agent failed\", \"request_id\": \"$REQUEST_ID\", \"fix_plan\": \"Investigate and fix: $BUG_REPORT\"}"

echo "=== [triage] Bug triage complete ===" >&2
