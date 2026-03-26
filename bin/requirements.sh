#!/usr/bin/env bash
set -euo pipefail

# PM Agent: analyze raw requirement, output structured PRD as JSON
# Reads REQUIREMENT from env, outputs PRD JSON to stdout

REPO="${REPO:-.}"
REQUIREMENT="${REQUIREMENT:-}"
PROJECT_NAME="${PROJECT_NAME:-untitled}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== [requirements] Starting PRD generation for: $PROJECT_NAME ===" >&2
echo "=== [requirements] Request ID: $REQUEST_ID ===" >&2

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/pm.md")" \
  --prompt "Analyze the following requirement for the project '$PROJECT_NAME' in the repo at $REPO.

Raw requirement from stakeholder:
$REQUIREMENT

Explore the existing codebase to understand context, then produce a complete PRD.
Output ONLY a valid JSON object matching the format specified in your instructions. No markdown wrapping." \
  --cwd "$REPO" \
  --output-format json \
  --max-turns 5 \
  2>/dev/null || echo "{\"error\": \"PM agent failed\", \"request_id\": \"$REQUEST_ID\", \"project_name\": \"$PROJECT_NAME\"}"

echo "=== [requirements] PRD generation complete ===" >&2
