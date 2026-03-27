#!/usr/bin/env bash
set -euo pipefail

# Task Breakdown: read Technical Design from stdin, output ordered task list

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"
source "$SCRIPT_DIR/lib/notify.sh"
source "$SCRIPT_DIR/lib/extract-json.sh"

DESIGN_DOC=$(cat)

echo "=== [tasks] Breaking down design into tasks for request: $REQUEST_ID ===" >&2

RAW_OUTPUT=$(cd "$REPO" && echo "Break down the following Technical Design Document into an ordered list of implementation tasks.

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
| claude -p \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/architect.md")

ADDITIONAL ROLE: You are now acting as both Architect and PM to break down a technical design into ordered, implementable tasks. Each task should be small enough for a single developer session." \
  2>/dev/null) || RAW_OUTPUT="{\"error\": \"task breakdown failed\", \"request_id\": \"$REQUEST_ID\"}"

TASKS_JSON=$(echo "$RAW_OUTPUT" | extract_json)
echo "$TASKS_JSON"

# 提取任务列表摘要
total=$(echo "$TASKS_JSON" | jq -r '.total_tasks // 0' 2>/dev/null || echo "0")
task_list=$(echo "$TASKS_JSON" | jq -r '.tasks[]? | "- \(.id): \(.description)"' 2>/dev/null || echo "- 任务解析中...")
notify_tasks_done "$REQUEST_ID" "共 **$total** 个任务：
$task_list"

echo "=== [tasks] Task breakdown complete ===" >&2
