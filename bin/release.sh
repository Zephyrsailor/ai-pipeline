#!/usr/bin/env bash
set -euo pipefail

# Release Agent: create PR, generate release notes

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"
source "$SCRIPT_DIR/lib/notify.sh"

START_TIME=$(date +%s)

echo "=== [release] Starting release process for request: $REQUEST_ID ===" >&2
notify_release_start "$REQUEST_ID"

RELEASE_OUTPUT=$(cd "$REPO" && echo "Execute the release process for this repo (request: $REQUEST_ID).

Steps:
1. Check git status and ensure working tree is clean
2. Create a pull request with a descriptive title and body
3. Include the request ID ($REQUEST_ID) in the PR description
4. Generate release notes summarizing all changes
5. Report the PR URL and release status

Output ONLY a valid JSON object matching the format specified in your instructions." \
| claude -p \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/release.md")" \
  --allowedTools "Read,Bash,Glob,Grep" \
  2>/dev/null) || RELEASE_OUTPUT="{\"error\": \"release agent failed\", \"request_id\": \"$REQUEST_ID\", \"deployed\": false}"

echo "$RELEASE_OUTPUT"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

pr_url=$(echo "$RELEASE_OUTPUT" | jq -r '.pr_url // "N/A"' 2>/dev/null || echo "N/A")
notify_release_done "$REQUEST_ID" "$pr_url"

echo "=== [release] Release process complete (${DURATION}s) ===" >&2
