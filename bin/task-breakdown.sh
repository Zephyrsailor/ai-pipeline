#!/usr/bin/env bash
set -euo pipefail

# Task Breakdown: read Technical Design from stdin, output ordered task list as JSON
# Combines architect + PM perspective to break design into implementable tasks

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

DESIGN_DOC=$(cat)

echo "=== [tasks] Breaking down design into tasks for request: $REQUEST_ID ===" >&2

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/architect.md")

ADDITIONAL ROLE: You are now acting as both Architect and PM to break down a technical design into ordered, implementable tasks. Each task should be small enough for a single developer session." \
  --prompt "Break down the following Technical Design Document into an ordered list of implementation tasks.

Technical Design:
$DESIGN_DOC

For each task, specify:
- A unique task ID (TASK-001, TASK-002, etc.)
- A clear description of what to implement
- Which files to create or modify
- Dependencies on other tasks
- Estimated complexity (small/medium/large)

Output ONLY a valid JSON object with this format:
{
  \"request_id\": \"$REQUEST_ID\",
  \"total_tasks\": N,
  \"tasks\": [
    {
      \"id\": \"TASK-001\",
      \"description\": \"What to implement\",
      \"files\": [\"path/to/file\"],
      \"depends_on\": [],
      \"complexity\": \"small|medium|large\"
    }
  ],
  \"implementation_order\": [\"TASK-001\", \"TASK-002\"],
  \"estimated_total_effort\": \"small|medium|large\"
}" \
  --cwd "$REPO" \
  --output-format json \
  --max-turns 3 \
  2>/dev/null || echo "{\"error\": \"task breakdown failed\", \"request_id\": \"$REQUEST_ID\"}"

echo "=== [tasks] Task breakdown complete ===" >&2
