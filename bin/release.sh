#!/usr/bin/env bash
set -euo pipefail

# Release Agent: create PR, verify CI, generate release notes, deploy

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

START_TIME=$(date +%s)

echo "=== [release] Starting release process for request: $REQUEST_ID ===" >&2

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/release.md")" \
  --prompt "Execute the release process for the repo at $REPO (request: $REQUEST_ID).

Steps:
1. Check git status and ensure working tree is clean
2. Create a pull request with a descriptive title and body
3. Include the request ID ($REQUEST_ID) in the PR description
4. Generate release notes summarizing all changes
5. Report the PR URL and release status

Output ONLY a valid JSON object matching the format specified in your instructions." \
  --cwd "$REPO" \
  --output-format json \
  --allowedTools "Read,Bash,Glob,Grep" \
  --max-turns 5 \
  2>/dev/null || echo "{\"error\": \"release agent failed\", \"request_id\": \"$REQUEST_ID\", \"deployed\": false}"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "=== [release] Release process complete (${DURATION}s) ===" >&2
