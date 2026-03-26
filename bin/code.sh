#!/usr/bin/env bash
set -euo pipefail

# Programmer Agent: implement the architecture plan
# Reads plan from stdin, invokes Claude Code to write code

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLAN=$(cat)

START_TIME=$(date +%s)

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/programmer.md")" \
  --prompt "Implement the following architecture plan. Work in the repo at $REPO.

Plan:
$PLAN

After implementation, commit your changes with a descriptive message." \
  --cwd "$REPO" \
  --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
  2>/dev/null || true

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Output structured result
jq -n \
  --arg rid "$REQUEST_ID" \
  --argjson dur "$DURATION" \
  '{request_id: $rid, phase: "code", duration_seconds: $dur, status: "completed"}'
