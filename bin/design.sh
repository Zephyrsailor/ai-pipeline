#!/usr/bin/env bash
set -euo pipefail

# Architect Agent: read PRD from stdin, output Technical Design Document as JSON

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PRD=$(cat)

echo "=== [design] Starting technical design for request: $REQUEST_ID ===" >&2

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/architect.md")" \
  --prompt "You are given the following Product Requirements Document (PRD). Analyze it, explore the codebase at $REPO, and produce a comprehensive Technical Design Document.

PRD:
$PRD

Output ONLY a valid JSON object matching the format specified in your instructions. No markdown wrapping." \
  --cwd "$REPO" \
  --output-format json \
  --max-turns 5 \
  2>/dev/null || echo "{\"error\": \"architect agent failed\", \"request_id\": \"$REQUEST_ID\"}"

echo "=== [design] Technical design complete ===" >&2
