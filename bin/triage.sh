#!/usr/bin/env bash
set -euo pipefail

# Triage Agent: analyze bug report, locate root cause, generate fix plan

REPO="${REPO:-.}"
BUG_REPORT="${BUG_REPORT:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/triage.md")" \
  --prompt "Analyze this bug report for the repo at $REPO:

$BUG_REPORT

Output ONLY a JSON object:
{
  \"severity\": \"critical|high|medium|low\",
  \"summary\": \"one line summary\",
  \"root_cause\": \"suspected root cause\",
  \"affected_files\": [\"file1.ts\", \"file2.ts\"],
  \"fix_plan\": \"step by step fix plan\"
}" \
  --cwd "$REPO" \
  --output-format json \
  --max-turns 5 \
  2>/dev/null || echo "{\"error\": \"triage agent failed\", \"fix_plan\": \"Investigate and fix: $BUG_REPORT\"}"
