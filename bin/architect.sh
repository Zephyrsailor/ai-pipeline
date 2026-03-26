#!/usr/bin/env bash
set -euo pipefail

# Architect Agent: analyze requirement, output technical plan as JSON
# Uses Claude Code CLI directly (autoresearch pattern: tool does the work, script captures output)

REPO="${REPO:-.}"
REQUEST="${REQUEST:-}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/architect.md")" \
  --prompt "Analyze this feature request for the repo at $REPO:

$REQUEST

Output ONLY a JSON object (no markdown, no explanation)." \
  --cwd "$REPO" \
  --output-format json \
  --max-turns 1 \
  2>/dev/null || echo "{\"error\": \"architect agent failed\", \"request_id\": \"$REQUEST_ID\"}"
