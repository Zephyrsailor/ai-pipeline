#!/usr/bin/env bash
set -euo pipefail

# Developer Agent: read task list from stdin, implement all tasks
# Invokes Claude Code with write permissions to implement code changes

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

TASKS=$(cat)

START_TIME=$(date +%s)

echo "=== [develop] Starting implementation for request: $REQUEST_ID ===" >&2

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/developer.md")" \
  --prompt "Implement the following tasks in the repo at $REPO. Work through them in the specified implementation order.

Task List:
$TASKS

After implementing each task:
1. Verify the code compiles/runs without errors
2. Commit with a descriptive message following the format: type(scope): description
3. Move to the next task

After all tasks are complete, output a JSON summary of what was done." \
  --cwd "$REPO" \
  --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
  2>/dev/null || true

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "=== [develop] Implementation complete (${DURATION}s) ===" >&2

# Output structured result
jq -n \
  --arg rid "$REQUEST_ID" \
  --argjson dur "$DURATION" \
  '{request_id: $rid, phase: "development", duration_seconds: $dur, status: "completed"}'
